import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:animation_maker/core/constants/animation_constants.dart';
import 'package:animation_maker/features/canvas/domain/entities/camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/camera_view_model.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_frame.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_transform_keyframe.dart';
import 'package:animation_maker/features/canvas/presentation/services/image_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_raster_paint_keys.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/entities/spatial_object.dart';
import 'package:animation_maker/features/canvas/domain/services/quadtree.dart';
import 'package:animation_maker/features/canvas/domain/services/frame_shape_resolver.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_hierarchy_service.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_merge_service.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_transformer.dart';
import 'package:animation_maker/features/canvas/data/serializers/canvas_document_codec.dart';
import 'package:animation_maker/features/canvas/presentation/models/brush_settings.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/models/joystick_mode.dart';
import 'package:animation_maker/features/canvas/presentation/models/point_mode_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_edit_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/style_edit_scope.dart';
import 'package:animation_maker/features/canvas/domain/entities/transform_handle.dart';
import 'package:animation_maker/features/canvas/domain/usecases/transform_session.dart';
import 'package:animation_maker/features/canvas/presentation/models/history_operation.dart';
import 'package:animation_maker/features/canvas/presentation/services/node_edit_service.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brushes/brush_type.dart';
import 'package:animation_maker/features/canvas/presentation/providers/repository_providers.dart';
import 'package:animation_maker/features/canvas/presentation/services/clipboard_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/keyframe_clipboard_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/document_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/history_manager.dart';
import 'package:animation_maker/features/canvas/presentation/services/selection_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/selection_utils.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_drawing_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_grouping_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/style_edit_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/stroke_drawing_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/tool_state_toggles.dart';
import 'package:animation_maker/features/canvas/presentation/services/transform_edit_persistence_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/transform_service.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/document_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/drawing_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/history_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/layer_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/selection_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/shape_operations_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/timeline_playback_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/tool_settings_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/transform_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/joystick_transform_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/node_edit_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/point_mode_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/linking_mode_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/object_keyframe_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/scene_camera_keyframe_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/scene_camera_view_model.dart';
import 'package:animation_maker/features/canvas/presentation/view_models/spatial_object_view_model.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

// Re-export models for backward compatibility
export 'package:animation_maker/features/canvas/presentation/models/brush_settings.dart';
export 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
export 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
export 'package:animation_maker/features/canvas/presentation/models/history_operation.dart';

class EditorViewModel extends Notifier<EditorState> {
  // Core services
  final DocumentService _document = DocumentService();
  final ToolStateToggles _toolToggles = ToolStateToggles();
  final SelectionService _selectionService = const SelectionService();
  final ShapeDrawingService _shapeDrawingService = const ShapeDrawingService();
  final ShapeGroupingService _shapeGroupingService = ShapeGroupingService();
  final ShapeMergeService _shapeMergeService = const ShapeMergeService();
  final TransformService _transformService = const TransformService();
  final SelectionUtils _selectionUtils = const SelectionUtils();
  final EditorClipboard _clipboard = EditorClipboard();
  final NodeEditService _nodeEditService = const NodeEditService();
  final ShapeHierarchyService _hierarchyService = const ShapeHierarchyService();
  final FrameShapeResolver _frameShapeResolver = const FrameShapeResolver();
  final StyleEditService _styleEditService = const StyleEditService();
  final TransformEditPersistenceService _transformEditPersistenceService =
      const TransformEditPersistenceService();

  // View models
  late final DrawingViewModel _drawingViewModel;
  late final SelectionViewModel _selectionViewModel;
  late final HistoryViewModel _historyViewModel;
  late final DocumentViewModel _documentViewModel;
  late final TransformViewModel _transformViewModel;
  late final ToolSettingsViewModel _toolSettingsViewModel;
  late final ShapeOperationsViewModel _shapeOperationsViewModel;
  late final LayerViewModel _layerViewModel;
  late final JoystickTransformViewModel _joystickTransformViewModel;
  late final NodeEditViewModel _nodeEditViewModel;
  late final PointModeViewModel _pointModeViewModel;
  late final LinkingModeViewModel _linkingModeViewModel;
  late final SpatialObjectViewModel _spatialObjectViewModel;
  late final CameraViewModel _cameraViewModel;
  late final SceneCameraViewModel _sceneCameraViewModel;
  late final SceneCameraKeyframeViewModel _sceneCameraKeyframeViewModel;
  late final ObjectKeyframeViewModel _objectKeyframeViewModel;
  final KeyframeClipboardService _keyframeClipboard =
      KeyframeClipboardService();
  late final TimelinePlaybackViewModel _timelinePlaybackViewModel;

  // Internal state
  int _shapeCounter = 0;
  int _layerCounter = 0;
  int _spatialCounter = 0;
  bool _selectionDirty = false;
  bool _pendingHistoryPush = false;
  Future<void>? _pendingEndDrawingCommit;
  Set<String>? _shapeDrawStartShapeIds;
  final List<String> _recentObjectTimelineSelectionIds = <String>[];

  /// Base shapes for the current frame BEFORE keyframe transforms are applied.
  /// Used to save clean (pre-keyframe) geometry to the document and history.
  List<Shape> _baseShapes = const [];

  static const int _maxRecentObjectTimelineTracks = 5;

  // Rotation session state (shared between joystick and handle rotation)
  double _lastAppliedRotationDelta = 0.0;
  Map<String, Offset> _baseChildPositions = const {};
  Map<String, double> _baseChildRotations = const {};

  void setIsInteractingWithCanvas(bool value) {
    state = state.copyWith(isInteractingWithCanvas: value);
  }

  void setViewportScale(double value) {
    if (state.viewportScale == value) return;
    state = state.copyWith(camera: state.camera.copyWith(zoom: value));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Camera Operations (delegated to CameraViewModel)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Sets the camera state directly.
  void setCamera(Camera camera) {
    state = _cameraViewModel.setCamera(state, camera);
  }

  /// Pans the camera by a screen-space delta.
  void panCamera(Offset screenDelta) {
    state = _cameraViewModel.pan(state, screenDelta);
  }

  /// Zooms to fit the artboard in the viewport.
  void fitCameraToArtboard(Size viewportSize) {
    state = _cameraViewModel.fitToArtboard(state, viewportSize);
  }

  /// Zooms to fit the current selection in the viewport.
  void fitCameraToSelection(Size viewportSize) {
    state = _cameraViewModel.fitToSelection(state, viewportSize);
  }

  /// Zooms to a specific level centered on a screen point.
  void zoomCameraToPoint(Offset screenPoint, Size viewportSize, double zoom) {
    state = _cameraViewModel.zoomToPoint(
      state: state,
      screenPoint: screenPoint,
      viewportSize: viewportSize,
      zoom: zoom,
    );
  }

  /// Zooms in by a fixed percentage.
  void zoomCameraIn(Size viewportSize) {
    state = _cameraViewModel.zoomIn(state, viewportSize);
  }

  /// Zooms out by a fixed percentage.
  void zoomCameraOut(Size viewportSize) {
    state = _cameraViewModel.zoomOut(state, viewportSize);
  }

  /// Sets zoom to exactly 100%.
  void setCameraActualSize() {
    state = _cameraViewModel.actualSize(state);
  }

  /// Resets camera to default view (fit artboard).
  void resetCamera(Size viewportSize) {
    state = _cameraViewModel.resetCamera(state, viewportSize);
  }

  /// Handles scroll wheel zoom.
  void handleCameraScrollZoom(
    Offset screenPoint,
    Size viewportSize,
    double scrollDelta,
  ) {
    state = _cameraViewModel.handleScrollZoom(
      state: state,
      screenPoint: screenPoint,
      viewportSize: viewportSize,
      scrollDelta: scrollDelta,
    );
  }

  /// Starts a pinch-zoom gesture.
  void startCameraPinchZoom(Offset screenFocalPoint, Size viewportSize) {
    _cameraViewModel.startPinchZoom(state, screenFocalPoint, viewportSize);
  }

  /// Updates pinch-zoom gesture.
  void updateCameraPinchZoom({
    required Offset screenFocalPoint,
    required Size viewportSize,
    required double scale,
    double? rotation,
  }) {
    state = _cameraViewModel.updatePinchZoom(
      state: state,
      screenFocalPoint: screenFocalPoint,
      viewportSize: viewportSize,
      scale: scale,
      rotation: rotation,
    );
  }

  /// Ends pinch-zoom gesture.
  void endCameraPinchZoom() {
    _cameraViewModel.endPinchZoom();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Joystick Transform (delegated to JoystickTransformViewModel)
  // ─────────────────────────────────────────────────────────────────────────────

  void toggleJoystickController() =>
      _joystickTransformViewModel.toggleJoystickController();

  void setJoystickMode(JoystickMode mode) =>
      _joystickTransformViewModel.setJoystickMode(mode);

  void startJoystickTransform() =>
      _joystickTransformViewModel.startJoystickTransform();

  void endJoystickTransform() =>
      _joystickTransformViewModel.endJoystickTransform();

  void applyJoystickMove(Offset delta) =>
      _joystickTransformViewModel.applyJoystickMove(delta);

  void applyJoystickScale(double factor) =>
      _joystickTransformViewModel.applyJoystickScale(factor);

  void applyJoystickScaleDirectional(double scaleX, double scaleY) =>
      _joystickTransformViewModel.applyJoystickScaleDirectional(scaleX, scaleY);

  void applyJoystickScaleWithHandle(
    TransformHandle handle,
    double factor,
    Offset? axis,
  ) => _joystickTransformViewModel.applyJoystickScaleWithHandle(
    handle,
    factor,
    axis,
  );

  void applyJoystickRotate(double deltaAngle) =>
      _joystickTransformViewModel.applyJoystickRotate(deltaAngle);

  // ─────────────────────────────────────────────────────────────────────────────
  // Scene Camera Operations (delegated to SceneCameraViewModel)
  // ─────────────────────────────────────────────────────────────────────────────

  void setSceneCamera(SceneCamera? camera) =>
      _sceneCameraViewModel.setSceneCamera(camera);

  void moveSceneCamera(Offset delta) =>
      _sceneCameraViewModel.moveSceneCamera(delta);

  void zoomSceneCamera(double factor) =>
      _sceneCameraViewModel.zoomSceneCamera(factor);

  void rotateSceneCamera(double deltaAngle) =>
      _sceneCameraViewModel.rotateSceneCamera(deltaAngle);

  void setSceneCameraPosition(Offset position) =>
      _sceneCameraViewModel.setSceneCameraPosition(position);

  void setSceneCameraSize(Size size) =>
      _sceneCameraViewModel.setSceneCameraSize(size);

  void setSceneCameraZoom(double zoom) =>
      _sceneCameraViewModel.setSceneCameraZoom(zoom);

  void setSceneCameraRotation(double rotation) =>
      _sceneCameraViewModel.setSceneCameraRotation(rotation);

  void resetSceneCamera() => _sceneCameraViewModel.resetSceneCamera();

  void fitSceneCameraToArtboard() =>
      _sceneCameraViewModel.fitSceneCameraToArtboard();

  // ─────────────────────────────────────────────────────────────────────────────
  // Scene Camera Keyframes (delegated to SceneCameraKeyframeViewModel)
  // ─────────────────────────────────────────────────────────────────────────────

  bool get hasSceneCameraKeyframeAtCurrentFrame =>
      _sceneCameraKeyframeViewModel.hasKeyframeAtCurrentFrame;

  List<int> get sceneCameraKeyframeFrames =>
      _sceneCameraKeyframeViewModel.keyframeFrames;

  void addOrUpdateSceneCameraKeyframeAtCurrentFrame() =>
      _sceneCameraKeyframeViewModel.addOrUpdateAtCurrentFrame();

  void deleteSceneCameraKeyframeAtCurrentFrame() =>
      _sceneCameraKeyframeViewModel.deleteAtCurrentFrame();

  bool copySceneCameraKeyframeAtCurrentFrame() =>
      _sceneCameraKeyframeViewModel.copyKeyframeAtCurrentFrame();

  bool pasteSceneCameraKeyframeAtCurrentFrame() =>
      _sceneCameraKeyframeViewModel.pasteKeyframeAtCurrentFrame();

  bool get canPasteCameraKeyframe =>
      _sceneCameraKeyframeViewModel.canPasteCameraKeyframe;

  Future<void> jumpToPreviousSceneCameraKeyframe() async {
    final frame = _sceneCameraKeyframeViewModel.previousKeyframeFrame();
    if (frame == null) return;
    await setCurrentFrame(frame);
  }

  Future<void> jumpToNextSceneCameraKeyframe() async {
    final frame = _sceneCameraKeyframeViewModel.nextKeyframeFrame();
    if (frame == null) return;
    await setCurrentFrame(frame);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Object Keyframes (delegated to ObjectKeyframeViewModel)
  // ─────────────────────────────────────────────────────────────────────────────

  bool get hasSelectedObjectKeyframeAtCurrentFrame =>
      _objectKeyframeViewModel.hasSelectedObjectKeyframeAtCurrentFrame;

  List<int> get selectedObjectKeyframeFrames =>
      _objectKeyframeViewModel.selectedObjectKeyframeFrames;

  Set<ObjectKeyChannel> get selectedObjectKeyChannelsAtCurrentFrame =>
      _objectKeyframeViewModel.selectedObjectKeyChannelsAtCurrentFrame;

  String? get selectedObjectKeyframeDisplayName =>
      _objectKeyframeViewModel.selectedObjectDisplayName();

  List<ObjectTimelineTrackViewData> get objectTimelineTrackViewData {
    _rememberObjectTimelineSelection(state.selectedShapeId);
    final timeline = state.document.objectTimeline;
    final shapesById = {for (final shape in state.shapes) shape.id: shape};
    _recentObjectTimelineSelectionIds.removeWhere(
      (shapeId) => !shapesById.containsKey(shapeId),
    );
    final tracks = _recentObjectTimelineSelectionIds
        .map((shapeId) {
          final shape = shapesById[shapeId]!;
          final displayName = (shape.name == null || shape.name!.trim().isEmpty)
              ? shape.id
              : shape.name!.trim();
          return ObjectTimelineTrackViewData(
            shapeId: shape.id,
            displayName: displayName,
            frames: timeline.keyframeFrames(shape.id),
          );
        })
        .toList(growable: false);
    return tracks;
  }

  void addOrUpdateSelectedObjectKeyframeAtCurrentFrame() =>
      _objectKeyframeViewModel.addOrUpdateSelectedObjectAtCurrentFrame();

  void addOrUpdateSelectedObjectKeyframeChannelAtCurrentFrame(
    ObjectKeyChannel channel,
  ) {
    addOrUpdateSelectedObjectKeyframeChannelsAtCurrentFrame(<ObjectKeyChannel>{
      channel,
    });
  }

  void addOrUpdateSelectedObjectKeyframeChannelsAtCurrentFrame(
    Set<ObjectKeyChannel> channels,
  ) {
    _objectKeyframeViewModel.addOrUpdateSelectedObjectChannelsAtCurrentFrame(
      channels,
    );
  }

  void setSelectedObjectKeyframeChannelsAtCurrentFrame(
    Set<ObjectKeyChannel> channels,
  ) {
    _objectKeyframeViewModel.setSelectedObjectChannelsAtCurrentFrame(channels);
  }

  void deleteSelectedObjectKeyframeAtCurrentFrame() =>
      _objectKeyframeViewModel.deleteSelectedObjectAtCurrentFrame();

  bool copySelectedObjectKeyframeAtCurrentFrame() =>
      _objectKeyframeViewModel.copySelectedObjectKeyframeAtCurrentFrame();

  bool pasteSelectedObjectKeyframeAtCurrentFrame() =>
      _objectKeyframeViewModel.pasteObjectKeyframeAtCurrentFrame();

  bool get canPasteObjectKeyframe =>
      _objectKeyframeViewModel.canPasteObjectKeyframe;

  /// Whether the keyframe clipboard has content that matches the current
  /// primary keyframe context (object vs. camera).
  bool canPasteKeyframe({required bool primaryTargetsObject}) {
    return primaryTargetsObject
        ? canPasteObjectKeyframe
        : canPasteCameraKeyframe;
  }

  Future<void> jumpToPreviousSelectedObjectKeyframe() async {
    final frame = _objectKeyframeViewModel
        .previousSelectedObjectKeyframeFrame();
    if (frame == null) return;
    await setCurrentFrame(frame);
  }

  Future<void> jumpToNextSelectedObjectKeyframe() async {
    final frame = _objectKeyframeViewModel.nextSelectedObjectKeyframeFrame();
    if (frame == null) return;
    await setCurrentFrame(frame);
  }

  bool get isTimelinePlaying => _timelinePlaybackViewModel.isPlaying;
  bool get autoKeyEnabled => state.autoKeyEnabled;
  StyleEditScope get styleEditScope => state.styleEditScope;

  void toggleTimelinePlayback() => _timelinePlaybackViewModel.togglePlayback();

  void playTimeline() => _timelinePlaybackViewModel.play();

  void pauseTimeline() => _timelinePlaybackViewModel.pause();

  void setAutoKeyEnabled(bool enabled) {
    if (state.autoKeyEnabled == enabled) return;
    state = state.copyWith(autoKeyEnabled: enabled);
  }

  void toggleAutoKeyEnabled() {
    setAutoKeyEnabled(!state.autoKeyEnabled);
  }

  void setStyleEditScope(StyleEditScope scope) {
    if (state.styleEditScope == scope) return;
    state = state.copyWith(styleEditScope: scope);
  }

  void toggleSceneCameraVisibility() {
    state = state.copyWith(sceneCameraVisible: !state.sceneCameraVisible);
  }

  // Helpers used by rotation operations
  Offset _rotatePoint(Offset point, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(
      point.dx * cos - point.dy * sin,
      point.dx * sin + point.dy * cos,
    );
  }

  Offset _pivotWorldForShape(Shape shape, Offset origin) {
    return shape.translation + origin + shape.transform.pivot;
  }

  @override
  EditorState build() {
    // Initialize view models
    _selectionViewModel = SelectionViewModel(
      selectionService: _selectionService,
      selectionUtils: _selectionUtils,
    );
    _historyViewModel = HistoryViewModel(documentService: _document);
    _documentViewModel = DocumentViewModel(
      documentService: _document,
      ref: ref,
    );
    _transformViewModel = TransformViewModel(
      transformService: _transformService,
    );
    _toolSettingsViewModel = ToolSettingsViewModel(toolToggles: _toolToggles);
    _shapeOperationsViewModel = ShapeOperationsViewModel(
      shapeGroupingService: _shapeGroupingService,
      shapeMergeService: _shapeMergeService,
      clipboard: _clipboard,
    );
    _drawingViewModel = DrawingViewModel(
      shapeDrawingService: _shapeDrawingService,
      shapeGroupingService: _shapeGroupingService,
    );
    _layerViewModel = LayerViewModel(
      getState: () => state,
      setState: (s) => state = s,
      pushHistory: _pushHistory,
      queueAutosave: _queueAutosave,
      loadFrame: _loadFrame,
      nextLayerId: _nextLayerId,
      nextShapeId: _nextShapeId,
    );
    _joystickTransformViewModel = JoystickTransformViewModel(
      getState: () => state,
      setState: (s) => state = s,
      getSelectedGroupShapes: _selectedGroupShapes,
      getSelectionBounds: _selectionBoundsFor,
      applyTransformedShapes: applyTransformedShapes,
      moveSelectedBy: moveSelectedBy,
      moveShapesByIds: _moveShapesByIds,
      finalizeSelectionEdit: finalizeSelectionEdit,
      hierarchyService: _hierarchyService,
    );
    _nodeEditViewModel = NodeEditViewModel(
      getState: () => state,
      setState: (s) => state = s,
      pushHistory: _pushHistory,
      queueAutosave: _queueAutosave,
      setShapesAndRebuild: _setShapesAndRebuild,
      rebuildQuadTree: rebuildQuadTree,
      setSelectionDirty: (v) => _selectionDirty = v,
      nextShapeId: _nextShapeId,
      nodeEditService: _nodeEditService,
    );
    _pointModeViewModel = PointModeViewModel(
      getState: () => state,
      setState: (s) => state = s,
      setShapesAndRebuild: (shapes, {String? selectedShapeId}) =>
          _setShapesAndRebuild(shapes, selectedShapeId: selectedShapeId),
      rebuildQuadTree: _document.rebuildQuadTree,
      pushHistory: _pushHistory,
      nextShapeId: _nextShapeId,
    );
    _linkingModeViewModel = LinkingModeViewModel(
      getState: () => state,
      setState: (s) => state = s,
      setShapesAndRebuild: _setShapesAndRebuild,
      pushHistory: _pushHistory,
      hierarchyService: _hierarchyService,
    );
    _spatialObjectViewModel = SpatialObjectViewModel(
      getState: () => state,
      setState: (s) => state = s,
      nextSpatialId: _nextSpatialId,
    );
    _cameraViewModel = CameraViewModel();
    _sceneCameraViewModel = SceneCameraViewModel(
      getState: () => state,
      setState: (s) => state = s,
    );
    _sceneCameraKeyframeViewModel = SceneCameraKeyframeViewModel(
      getState: () => state,
      setState: (s) => state = s,
      pushHistory: _pushHistory,
      clipboardService: _keyframeClipboard,
    );
    _objectKeyframeViewModel = ObjectKeyframeViewModel(
      getState: () => state,
      setState: (s) => state = s,
      pushHistory: _pushHistory,
      clipboardService: _keyframeClipboard,
    );
    _timelinePlaybackViewModel = TimelinePlaybackViewModel(
      getState: () => state,
      setState: (s) => state = s,
      setCurrentFrame: setCurrentFrame,
    );

    final initial = EditorState.initial();
    _document.resetHistory(
      shapes: initial.shapes,
      selectedId: initial.selectedShapeId,
      selectedIds: initial.selectedShapeIds,
      frameIndex: initial.currentFrame,
      activeLayerId: initial.activeLayerId,
      sceneCameraTimeline: initial.document.sceneCameraTimeline,
      objectTimeline: initial.document.objectTimeline,
      sceneCamera: initial.sceneCamera,
    );
    _document.rebuildQuadTree(initial.shapes);
    _syncIdCounters(initial.document);

    ref.onDispose(() {
      _timelinePlaybackViewModel.dispose();
      _documentViewModel.dispose();
    });
    return initial;
  }

  void setActiveTool(EditorTool tool) {
    state = _toolSettingsViewModel.setActiveTool(state, tool);
    if (tool != EditorTool.brush &&
        tool != EditorTool.eraser &&
        _drawingViewModel.isDrawing) {
      final cancelResult = _drawingViewModel.cancelDrawing(state);
      if (cancelResult.state != null) {
        state = cancelResult.state!;
      }
    }
    // Exit node edit mode when switching to other tools
    if (tool != EditorTool.nodeEdit && state.isNodeEditMode) {
      state = state.copyWith(nodeEditState: NodeEditState.initial);
    }
    // Exit spatial draw mode when leaving brush
    if (tool != EditorTool.brush && state.isSpatialDrawMode) {
      state = state.copyWith(
        isSpatialDrawMode: false,
        clearActiveSpatialObjectId: true,
      );
    }
    // Auto-create scene camera and open tool panel when entering camera mode
    if (tool == EditorTool.camera) {
      if (state.sceneCamera == null) {
        final sampled = _sceneCameraKeyframeViewModel.sampleCameraForFrame(
          state.currentFrame,
          fallback: SceneCamera.fromDocument(state.document.size),
        );
        state = state.copyWith(
          sceneCamera: sampled ?? SceneCamera.fromDocument(state.document.size),
        );
      }
      if (!state.isToolPanelOpen) {
        state = state.copyWith(isToolPanelOpen: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Spatial Object Methods (delegated to SpatialObjectViewModel)
  // ─────────────────────────────────────────────────────────────────────────────

  void toggleSpatialDrawMode() =>
      _spatialObjectViewModel.toggleSpatialDrawMode();
  void setSpatialDrawMode(bool value) =>
      _spatialObjectViewModel.setSpatialDrawMode(value);
  bool startEditingSpatialObject(String spatialId) {
    final exists = state.spatialObjects.any(
      (spatial) => spatial.id == spatialId,
    );
    if (!exists) return false;
    if (state.activeTool != EditorTool.brush) {
      setActiveTool(EditorTool.brush);
    }
    return _spatialObjectViewModel.startEditingSpatialObject(spatialId);
  }

  String? _ensureActiveSpatialObjectId() =>
      _spatialObjectViewModel.ensureActiveSpatialObjectId();
  void _attachShapesToSpatial(String spatialId, List<Shape> shapes) =>
      _spatialObjectViewModel.attachShapesToSpatial(spatialId, shapes);

  // ─────────────────────────────────────────────────────────────────────────────
  // Node Editing Methods (delegated to NodeEditViewModel)
  // ─────────────────────────────────────────────────────────────────────────────

  bool enterNodeEditMode() => _nodeEditViewModel.enterNodeEditMode();
  void exitNodeEditMode() => _nodeEditViewModel.exitNodeEditMode();
  bool selectedShapeHasMultipleContours() =>
      _nodeEditViewModel.selectedShapeHasMultipleContours();
  int getSelectedShapeContourCount() =>
      _nodeEditViewModel.getSelectedShapeContourCount();
  void refreshWeightedEditState() =>
      _nodeEditViewModel.refreshWeightedEditState();
  bool explodeSelectedContours() =>
      _nodeEditViewModel.explodeSelectedContours();
  bool convertSelectedToPath() => _nodeEditViewModel.convertSelectedToPath();
  bool convertAndEditNodes() => _nodeEditViewModel.convertAndEditNodes();
  void updateNodeEditState(NodeEditState newState) =>
      _nodeEditViewModel.updateNodeEditState(newState);
  void setNodeEditState(NodeEditState newState) =>
      _nodeEditViewModel.setNodeEditState(newState);
  void selectNodes(Set<int> indices) => _nodeEditViewModel.selectNodes(indices);
  void toggleNodeSelection(int index) =>
      _nodeEditViewModel.toggleNodeSelection(index);
  void clearNodeSelection() => _nodeEditViewModel.clearNodeSelection();
  void selectAllNodes() => _nodeEditViewModel.selectAllNodes();
  void moveSelectedNodes(Offset delta) =>
      _nodeEditViewModel.moveSelectedNodes(delta);
  void setActiveContour(int contourIndex) =>
      _nodeEditViewModel.setActiveContour(contourIndex);
  void nextContour() => _nodeEditViewModel.nextContour();
  void previousContour() => _nodeEditViewModel.previousContour();
  int getActiveContourIndex() => _nodeEditViewModel.getActiveContourIndex();
  void beginNodeDrag(Map<int, Offset> startPositions) =>
      _nodeEditViewModel.beginNodeDrag(startPositions);
  void endNodeDrag() => _nodeEditViewModel.endNodeDrag();
  int? getSelectedShapePointCount() =>
      _nodeEditViewModel.getSelectedShapePointCount();
  void updateShape(Shape updated) => _nodeEditViewModel.updateShape(updated);
  bool canEnterNodeEditMode(Shape? shape) =>
      _nodeEditViewModel.canEnterNodeEditMode(shape);

  void setSelectionMode(SelectionMode mode) {
    state = _selectionViewModel.setSelectionMode(state, mode);
  }

  void setSelection(List<String> ids) {
    state = _selectionViewModel.setSelection(state, ids);
    _rememberObjectTimelineSelection(state.selectedShapeId);
  }

  void setPivotSnap({bool? enabled, double? strength}) {
    state = _toolSettingsViewModel.setPivotSnap(
      state,
      enabled: enabled,
      strength: strength,
    );
  }

  void setPivotFlipWithObject(bool flip) {
    state = _toolSettingsViewModel.setPivotFlipWithObject(state, flip);
  }

  void setStrokeScaleWithShape(bool value) {
    state = _toolSettingsViewModel.setStrokeScaleWithShape(state, value);
  }

  void selectShape(String? shapeId) {
    state = _selectionViewModel.selectShape(state, shapeId);
    _rememberObjectTimelineSelection(state.selectedShapeId);
  }

  void selectNextShape() => _selectShapeByOffset(1);

  void selectPreviousShape() => _selectShapeByOffset(-1);

  void _selectShapeByOffset(int delta) {
    if (state.selectionMode != SelectionMode.single) return;
    final shapes = state.shapes;
    if (shapes.isEmpty) return;

    final selectedId = state.selectedShapeId;
    final currentIndex = selectedId == null
        ? -1
        : shapes.indexWhere((shape) => shape.id == selectedId);

    int nextIndex;
    if (currentIndex < 0) {
      nextIndex = delta >= 0 ? 0 : shapes.length - 1;
    } else {
      final raw = currentIndex + delta;
      nextIndex = ((raw % shapes.length) + shapes.length) % shapes.length;
    }

    state = _selectionViewModel.selectShape(state, shapes[nextIndex].id);
    _rememberObjectTimelineSelection(state.selectedShapeId);
  }

  void setShapes(List<Shape> shapes) {
    _setShapesAndRebuild(shapes);
    _pushHistory();
  }

  Future<void> setCurrentFrame(int frame) async {
    if (frame == state.currentFrame) return;
    await _loadFrame(layerId: state.activeLayerId, frameIndex: frame);
  }

  Future<void> setActiveLayer(String layerId) async {
    if (layerId == state.activeLayerId) return;
    await _loadFrame(layerId: layerId, frameIndex: state.currentFrame);
  }

  Future<void> addLayer({String? name, bool makeActive = true}) async {
    final id = _nextLayerId();
    final frameIndex = state.currentFrame;
    final layer = CanvasLayer(
      id: id,
      name: name ?? 'Layer ${_layerCounter}',
      frames: {frameIndex: CanvasFrame(index: frameIndex)},
    );
    final nextFrameCount = frameIndex >= state.document.frameCount
        ? frameIndex + 1
        : state.document.frameCount;
    final updated = state.document
        .upsertLayer(layer)
        .copyWith(updatedAt: DateTime.now(), frameCount: nextFrameCount);
    state = state.copyWith(
      document: updated,
      activeLayerId: makeActive ? id : state.activeLayerId,
    );
    if (makeActive) {
      await _loadFrame(layerId: id, frameIndex: frameIndex);
    }
    _queueAutosave();
  }

  void toggleLayerVisibility(String layerId) {
    final layer = state.document.layerById(layerId);
    if (layer == null) return;
    final updated = layer.copyWith(isVisible: !layer.isVisible);
    final nextDocument = state.document
        .upsertLayer(updated)
        .copyWith(updatedAt: DateTime.now());
    state = state.copyWith(document: nextDocument);
    _queueAutosave();
  }

  void toggleLayerLock(String layerId) {
    final layer = state.document.layerById(layerId);
    if (layer == null) return;
    final updated = layer.copyWith(isLocked: !layer.isLocked);
    final nextDocument = state.document
        .upsertLayer(updated)
        .copyWith(updatedAt: DateTime.now());
    state = state.copyWith(document: nextDocument);
    _queueAutosave();
  }

  // Layer management methods (delegated to LayerViewModel)
  void renameLayer(String layerId, String newName) =>
      _layerViewModel.renameLayer(layerId, newName);

  Future<void> deleteLayer(String layerId) =>
      _layerViewModel.deleteLayer(layerId);

  Future<void> duplicateLayer(String layerId) =>
      _layerViewModel.duplicateLayer(layerId);

  void reorderLayers(int oldIndex, int newIndex) =>
      _layerViewModel.reorderLayers(oldIndex, newIndex);

  Future<void> mergeLayerDown(String layerId) =>
      _layerViewModel.mergeLayerDown(layerId);

  void setLayerOpacity(String layerId, double opacity) =>
      _layerViewModel.setLayerOpacity(layerId, opacity);

  void setLayerBlendMode(String layerId, BlendMode blendMode) =>
      _layerViewModel.setLayerBlendMode(layerId, blendMode);

  void toggleShapeVisibility(String shapeId) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    final shape = location.shapes[location.index];
    final updated = shape.copyWith(isVisible: !shape.isVisible);
    if (state.styleEditScope.isGlobal) {
      _applyGlobalStylePatch(
        shapeIds: <String>{shapeId},
        patch: ShapeStylePatch(isVisible: updated.isVisible),
        addToHistory: false,
      );
      _queueAutosave();
      return;
    }

    final nextShapes = List<Shape>.from(location.shapes)
      ..[location.index] = updated;
    if (location.layerId == state.activeLayerId) {
      _setShapesAndRebuild(
        nextShapes,
        nonPersistentShapeIds: _nonPersistentTransformShapeIds(<String>[
          shapeId,
        ]),
      );
      _syncObjectKeyframesForEditedShapeIds(
        <String>[shapeId],
        channels: const <ObjectKeyChannel>{ObjectKeyChannel.visibility},
      );
    } else {
      _applyLayerShapes(location.layerId, nextShapes);
    }
    _queueAutosave();
  }

  void toggleShapeLock(String shapeId) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    final shape = location.shapes[location.index];
    final updated = shape.copyWith(isLocked: !shape.isLocked);
    final nextShapes = List<Shape>.from(location.shapes)
      ..[location.index] = updated;
    _applyLayerShapes(location.layerId, nextShapes);
    _queueAutosave();
  }

  void reorderShapesInLayer(String layerId, int oldIndex, int newIndex) {
    final layer = state.document.layerById(layerId);
    if (layer == null) return;
    final frame = layer.frameAt(state.currentFrame);
    final shapes = List<Shape>.from(frame.shapes);
    if (oldIndex < 0 || oldIndex >= shapes.length) return;
    if (newIndex < 0 || newIndex >= shapes.length) return;
    final item = shapes.removeAt(oldIndex);
    shapes.insert(newIndex, item);
    // Apply to the current frame first.
    _applyLayerShapes(layerId, shapes);
    // Propagate the new order to all other frames.
    final orderedIds = shapes.map((s) => s.id).toList(growable: false);
    final propagated = _reorderShapeInAllFrames(
      document: state.document,
      layerId: layerId,
      orderedShapeIds: orderedIds,
    );
    if (!identical(propagated, state.document)) {
      state = state.copyWith(document: propagated);
    }
    _pushHistory();
    _queueAutosave();
  }

  void moveShapeToLayer(String shapeId, String targetLayerId) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    if (location.layerId == targetLayerId) {
      // Same layer — just ungroup and move to end on current frame, then
      // propagate the new order.
      final layer = state.document.layerById(targetLayerId);
      if (layer == null) return;
      final shapes = List<Shape>.from(layer.frameAt(state.currentFrame).shapes);
      final item = shapes.removeAt(location.index);
      shapes.add(item.copyWith(clearGroupId: true));
      _applyLayerShapes(targetLayerId, shapes);
      // Propagate group clear across all frames.
      var doc = _updateShapeInAllFrames(
        document: state.document,
        layerId: targetLayerId,
        shapeId: shapeId,
        transform: (s) => s.copyWith(clearGroupId: true),
      );
      // Propagate order across all frames.
      final orderedIds = shapes.map((s) => s.id).toList(growable: false);
      doc = _reorderShapeInAllFrames(
        document: doc,
        layerId: targetLayerId,
        orderedShapeIds: orderedIds,
      );
      if (!identical(doc, state.document)) {
        state = state.copyWith(document: doc);
      }
      _pushHistory();
      _queueAutosave();
      return;
    }
    final sourceLayer = state.document.layerById(location.layerId);
    final targetLayer = state.document.layerById(targetLayerId);
    if (sourceLayer == null || targetLayer == null) return;

    // Apply current frame changes for display.
    final sourceShapes = List<Shape>.from(
      sourceLayer.frameAt(state.currentFrame).shapes,
    )..removeAt(location.index);
    final targetShapes = List<Shape>.from(
      targetLayer.frameAt(state.currentFrame).shapes,
    )..add(location.shapes[location.index].copyWith(clearGroupId: true));

    _applyLayerShapes(
      location.layerId,
      sourceShapes,
      rebuildQuadTree: location.layerId == state.activeLayerId,
    );
    _applyLayerShapes(
      targetLayerId,
      targetShapes,
      rebuildQuadTree: targetLayerId == state.activeLayerId,
    );

    // Propagate the move across all frames.
    final propagated = _moveShapesBetweenLayersInAllFrames(
      document: state.document,
      sourceLayerId: location.layerId,
      targetLayerId: targetLayerId,
      shapeIds: {shapeId},
      transformShape: (s) => s.copyWith(clearGroupId: true),
    );
    if (!identical(propagated, state.document)) {
      state = state.copyWith(document: propagated);
    }

    if (state.selectedShapeId == shapeId &&
        location.layerId != state.activeLayerId) {
      state = state.copyWith(clearSelection: true);
    }
    _pushHistory();
    _queueAutosave();
  }

  void moveShapeToLayerAtIndex(
    String shapeId,
    String targetLayerId,
    int targetIndex, {
    bool clearGroup = true,
  }) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    final sourceLayer = state.document.layerById(location.layerId);
    final targetLayer = state.document.layerById(targetLayerId);
    if (sourceLayer == null || targetLayer == null) return;

    if (location.layerId == targetLayerId) {
      final shapes = List<Shape>.from(
        targetLayer.frameAt(state.currentFrame).shapes,
      );
      final fromIndex = location.index;
      if (fromIndex < 0 || fromIndex >= shapes.length) return;
      final clampedTarget = targetIndex.clamp(0, shapes.length);
      final item = shapes.removeAt(fromIndex);
      final moving = clearGroup ? item.copyWith(clearGroupId: true) : item;
      var insertIndex = clampedTarget;
      if (fromIndex < insertIndex) {
        insertIndex -= 1;
      }
      shapes.insert(insertIndex, moving);
      _applyLayerShapes(targetLayerId, shapes);
      // Propagate group clear and order across all frames.
      var doc = state.document;
      if (clearGroup) {
        doc = _updateShapeInAllFrames(
          document: doc,
          layerId: targetLayerId,
          shapeId: shapeId,
          transform: (s) => s.copyWith(clearGroupId: true),
        );
      }
      final orderedIds = shapes.map((s) => s.id).toList(growable: false);
      doc = _reorderShapeInAllFrames(
        document: doc,
        layerId: targetLayerId,
        orderedShapeIds: orderedIds,
      );
      if (!identical(doc, state.document)) {
        state = state.copyWith(document: doc);
      }
      _pushHistory();
      _queueAutosave();
      return;
    }

    final sourceShapes = List<Shape>.from(
      sourceLayer.frameAt(state.currentFrame).shapes,
    );
    final moving = sourceShapes.removeAt(location.index);
    final targetShapes = List<Shape>.from(
      targetLayer.frameAt(state.currentFrame).shapes,
    );
    final clampedTarget = targetIndex.clamp(0, targetShapes.length);
    final resolved = clearGroup ? moving.copyWith(clearGroupId: true) : moving;
    targetShapes.insert(clampedTarget, resolved);

    _applyLayerShapes(
      location.layerId,
      sourceShapes,
      rebuildQuadTree: location.layerId == state.activeLayerId,
    );
    _applyLayerShapes(
      targetLayerId,
      targetShapes,
      rebuildQuadTree: targetLayerId == state.activeLayerId,
    );
    // Propagate the move across all frames.
    var doc = _moveShapesBetweenLayersInAllFrames(
      document: state.document,
      sourceLayerId: location.layerId,
      targetLayerId: targetLayerId,
      shapeIds: {shapeId},
      transformShape: clearGroup ? (s) => s.copyWith(clearGroupId: true) : null,
    );
    // Propagate the order within the target layer.
    final orderedIds = targetShapes.map((s) => s.id).toList(growable: false);
    doc = _reorderShapeInAllFrames(
      document: doc,
      layerId: targetLayerId,
      orderedShapeIds: orderedIds,
    );
    if (!identical(doc, state.document)) {
      state = state.copyWith(document: doc);
    }
    _pushHistory();
    _queueAutosave();
  }

  void moveShapeWithinGroupAtIndex(
    String targetLayerId,
    String groupId,
    String shapeId,
    int targetIndex,
  ) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    final sourceLayer = state.document.layerById(location.layerId);
    final targetLayer = state.document.layerById(targetLayerId);
    if (sourceLayer == null || targetLayer == null) return;

    if (location.layerId == targetLayerId) {
      final shapes = List<Shape>.from(
        targetLayer.frameAt(state.currentFrame).shapes,
      );
      final fromIndex = shapes.indexWhere((s) => s.id == shapeId);
      if (fromIndex == -1) return;
      final moving = shapes.removeAt(fromIndex).copyWith(groupId: groupId);
      final groupIndices = <int>[];
      for (var i = 0; i < shapes.length; i++) {
        if (shapes[i].groupId == groupId) {
          groupIndices.add(i);
        }
      }
      final clamped = targetIndex.clamp(0, groupIndices.length);
      final insertIndex = groupIndices.isEmpty
          ? clamped.clamp(0, shapes.length)
          : (clamped == groupIndices.length
                ? groupIndices.last + 1
                : groupIndices[clamped]);
      shapes.insert(insertIndex, moving);
      _applyLayerShapes(targetLayerId, shapes);
      // Propagate group assignment and order across all frames.
      var doc = _updateShapeInAllFrames(
        document: state.document,
        layerId: targetLayerId,
        shapeId: shapeId,
        transform: (s) => s.copyWith(groupId: groupId),
      );
      final orderedIds = shapes.map((s) => s.id).toList(growable: false);
      doc = _reorderShapeInAllFrames(
        document: doc,
        layerId: targetLayerId,
        orderedShapeIds: orderedIds,
      );
      if (!identical(doc, state.document)) {
        state = state.copyWith(document: doc);
      }
      _pushHistory();
      _queueAutosave();
      return;
    }

    final sourceShapes = List<Shape>.from(
      sourceLayer.frameAt(state.currentFrame).shapes,
    );
    final movingIndex = sourceShapes.indexWhere((s) => s.id == shapeId);
    if (movingIndex == -1) return;
    final moving = sourceShapes
        .removeAt(movingIndex)
        .copyWith(groupId: groupId);
    final targetShapes = List<Shape>.from(
      targetLayer.frameAt(state.currentFrame).shapes,
    );
    final groupIndices = <int>[];
    for (var i = 0; i < targetShapes.length; i++) {
      if (targetShapes[i].groupId == groupId) {
        groupIndices.add(i);
      }
    }
    final clamped = targetIndex.clamp(0, groupIndices.length);
    final insertIndex = groupIndices.isEmpty
        ? clamped.clamp(0, targetShapes.length)
        : (clamped == groupIndices.length
              ? groupIndices.last + 1
              : groupIndices[clamped]);
    targetShapes.insert(insertIndex, moving);

    _applyLayerShapes(
      location.layerId,
      sourceShapes,
      rebuildQuadTree: location.layerId == state.activeLayerId,
    );
    _applyLayerShapes(
      targetLayerId,
      targetShapes,
      rebuildQuadTree: targetLayerId == state.activeLayerId,
    );
    // Propagate the cross-layer move and group assignment across all frames.
    var doc = _moveShapesBetweenLayersInAllFrames(
      document: state.document,
      sourceLayerId: location.layerId,
      targetLayerId: targetLayerId,
      shapeIds: {shapeId},
      transformShape: (s) => s.copyWith(groupId: groupId),
    );
    final orderedIds = targetShapes.map((s) => s.id).toList(growable: false);
    doc = _reorderShapeInAllFrames(
      document: doc,
      layerId: targetLayerId,
      orderedShapeIds: orderedIds,
    );
    if (!identical(doc, state.document)) {
      state = state.copyWith(document: doc);
    }
    _pushHistory();
    _queueAutosave();
  }

  void moveGroupToLayer(String groupId, String targetLayerId) {
    final sourceLayerId = _findLayerIdForGroup(groupId);
    if (sourceLayerId == null || sourceLayerId == targetLayerId) return;
    final sourceLayer = state.document.layerById(sourceLayerId);
    final targetLayer = state.document.layerById(targetLayerId);
    if (sourceLayer == null || targetLayer == null) return;
    final sourceShapes = List<Shape>.from(
      sourceLayer.frameAt(state.currentFrame).shapes,
    );
    final moving = sourceShapes.where((s) => s.groupId == groupId).toList();
    if (moving.isEmpty) return;
    final movingIds = moving.map((s) => s.id).toSet();
    sourceShapes.removeWhere((s) => s.groupId == groupId);
    final targetShapes = List<Shape>.from(
      targetLayer.frameAt(state.currentFrame).shapes,
    )..addAll(moving);

    _applyLayerShapes(
      sourceLayerId,
      sourceShapes,
      rebuildQuadTree: sourceLayerId == state.activeLayerId,
    );
    _applyLayerShapes(
      targetLayerId,
      targetShapes,
      rebuildQuadTree: targetLayerId == state.activeLayerId,
    );
    // Propagate the group move across all frames.
    final propagated = _moveShapesBetweenLayersInAllFrames(
      document: state.document,
      sourceLayerId: sourceLayerId,
      targetLayerId: targetLayerId,
      shapeIds: movingIds,
    );
    if (!identical(propagated, state.document)) {
      state = state.copyWith(document: propagated);
    }
    _pushHistory();
    _queueAutosave();
  }

  void moveShapeToGroup(String shapeId, String? groupId) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    final shape = location.shapes[location.index];
    final updated = shape.copyWith(
      groupId: groupId,
      clearGroupId: groupId == null,
    );
    final nextShapes = List<Shape>.from(location.shapes)
      ..[location.index] = updated;
    _applyLayerShapes(location.layerId, nextShapes);
    // Propagate group assignment across all frames.
    final propagated = _updateShapeInAllFrames(
      document: state.document,
      layerId: location.layerId,
      shapeId: shapeId,
      transform: (s) =>
          s.copyWith(groupId: groupId, clearGroupId: groupId == null),
    );
    if (!identical(propagated, state.document)) {
      state = state.copyWith(document: propagated);
    }
    _pushHistory();
    _queueAutosave();
  }

  void createGroupFromShapes(List<String> shapeIds) {
    if (shapeIds.length < 2) return;
    final targetLayerId = _findLayerIdForShape(shapeIds.first);
    if (targetLayerId == null) return;
    final groupId = _shapeGroupingService.nextGroupId();

    // Track which shapes need to move between layers.
    final crossLayerMoves =
        <String, Set<String>>{}; // sourceLayerId -> shapeIds

    final updatedByLayer = <String, List<Shape>>{};
    for (final layer in state.document.layers) {
      final frame = layer.frameAt(state.currentFrame);
      updatedByLayer[layer.id] = List<Shape>.from(frame.shapes);
    }

    for (final id in shapeIds) {
      final layerId = _findLayerIdForShape(id);
      if (layerId == null) continue;
      final shapes = updatedByLayer[layerId];
      if (shapes == null) continue;
      final index = shapes.indexWhere((s) => s.id == id);
      if (index == -1) continue;
      final shape = shapes[index];
      if (layerId != targetLayerId) {
        shapes.removeAt(index);
        updatedByLayer[targetLayerId] ??= [];
        updatedByLayer[targetLayerId]!.add(shape.copyWith(groupId: groupId));
        crossLayerMoves.putIfAbsent(layerId, () => <String>{}).add(id);
      } else {
        shapes[index] = shape.copyWith(groupId: groupId);
      }
    }

    for (final entry in updatedByLayer.entries) {
      _applyLayerShapes(
        entry.key,
        entry.value,
        rebuildQuadTree: entry.key == state.activeLayerId,
      );
    }

    // Propagate cross-layer moves across all frames.
    var doc = state.document;
    for (final entry in crossLayerMoves.entries) {
      doc = _moveShapesBetweenLayersInAllFrames(
        document: doc,
        sourceLayerId: entry.key,
        targetLayerId: targetLayerId,
        shapeIds: entry.value,
        transformShape: (s) => s.copyWith(groupId: groupId),
      );
    }
    // Propagate group assignment for shapes that stayed in the target layer.
    final stayedInTarget = shapeIds
        .where((id) => !crossLayerMoves.values.any((s) => s.contains(id)))
        .toSet();
    for (final id in stayedInTarget) {
      doc = _updateShapeInAllFrames(
        document: doc,
        layerId: targetLayerId,
        shapeId: id,
        transform: (s) => s.copyWith(groupId: groupId),
      );
    }
    if (!identical(doc, state.document)) {
      state = state.copyWith(document: doc);
    }
    _pushHistory();
    _queueAutosave();
  }

  void ungroupShapes(String groupId) {
    final layerId = _findLayerIdForGroup(groupId);
    if (layerId == null) return;
    final layer = state.document.layerById(layerId);
    if (layer == null) return;
    final shapes = List<Shape>.from(layer.frameAt(state.currentFrame).shapes);
    final ungroupedIds = <String>[];
    var changed = false;
    for (var i = 0; i < shapes.length; i++) {
      if (shapes[i].groupId == groupId) {
        shapes[i] = shapes[i].copyWith(clearGroupId: true);
        ungroupedIds.add(shapes[i].id);
        changed = true;
      }
    }
    if (!changed) return;
    _applyLayerShapes(layerId, shapes);
    // Propagate group removal across all frames.
    var doc = state.document;
    for (final id in ungroupedIds) {
      doc = _updateShapeInAllFrames(
        document: doc,
        layerId: layerId,
        shapeId: id,
        transform: (s) => s.copyWith(clearGroupId: true),
      );
    }
    if (!identical(doc, state.document)) {
      state = state.copyWith(document: doc);
    }
    _pushHistory();
    _queueAutosave();
  }

  void deleteGroup(String groupId) {
    final layerId = _findLayerIdForGroup(groupId);
    if (layerId == null) return;
    final layer = state.document.layerById(layerId);
    if (layer == null) return;
    final shapes = layer.frameAt(state.currentFrame).shapes;
    final ids = shapes
        .where((shape) => shape.groupId == groupId)
        .map((shape) => shape.id)
        .toSet();
    if (ids.isEmpty) return;
    _deleteShapeIdsEverywhere(ids, forceClearSelection: false);
  }

  void updateDocumentMetadata({
    String? title,
    Size? size,
    double? fps,
    int? frameCount,
    CanvasBackground? background,
  }) {
    final normalizedFrameCount = frameCount?.clamp(1, 1000000);
    final next = state.document.copyWith(
      title: title,
      size: size,
      background: background,
      fps: fps,
      frameCount: normalizedFrameCount,
      updatedAt: DateTime.now(),
    );
    final maxFrameIndex = next.frameCount - 1;
    final needsClamp = state.currentFrame > maxFrameIndex;
    state = state.copyWith(
      document: next,
      currentFrame: needsClamp ? maxFrameIndex : state.currentFrame,
    );
    if (needsClamp) {
      unawaited(
        _loadFrame(layerId: state.activeLayerId, frameIndex: maxFrameIndex),
      );
    }
    if (size != null) {
      updateCanvasSize(size);
    }
    if (fps != null || frameCount != null) {
      _timelinePlaybackViewModel.restartIfPlaying();
    }
    _queueAutosave();
  }

  void updateCanvasSize(Size size) {
    return;
  }

  void togglePropertiesPanel() {
    state = _toolSettingsViewModel.togglePropertiesPanel(state);
  }

  void toggleLayersPanel() {
    state = _toolSettingsViewModel.toggleLayersPanel(state);
  }

  void setLeftPanelTab(LeftPanelTab tab) {
    state = _toolSettingsViewModel.setLeftPanelTab(state, tab);
  }

  void toggleToolPanel() {
    state = _toolSettingsViewModel.toggleToolPanel(state);
  }

  Future<void> saveDocument({bool flush = true}) async {
    await _documentViewModel.saveDocument(flush: flush);
    await _documentViewModel.saveDocumentInternal(state.document);
  }

  void _queueAutosave() {
    _documentViewModel.queueAutosave();
  }

  Future<void> loadDocument(String id) async {
    final document = await _documentViewModel.loadDocument(id);
    if (document == null) return;
    await _applyDocument(document);
  }

  String exportDocumentJson() {
    return CanvasDocumentCodec.encode(state.document);
  }

  Future<void> importDocumentJson(String raw) async {
    final document = CanvasDocumentCodec.decode(raw);
    await _applyDocument(document);
  }

  bool get canUndo => _historyViewModel.canUndo;
  bool get canRedo => _historyViewModel.canRedo;
  bool get canPaste => _shapeOperationsViewModel.canPaste;
  bool get isHistoryBusy => _historyViewModel.isHistoryBusy;

  // History queue processing is now handled by HistoryViewModel

  bool _isHistoryApplyStale(int generation) =>
      _historyViewModel.isHistoryApplyStale(generation);

  Future<void> undo() async {
    await _awaitPendingEndDrawingCommit();
    final snap = await _historyViewModel.undo();
    if (snap == null) return;
    _historyViewModel.scheduleHistoryApply(
      snap,
      HistoryOperationType.undo,
      _applySnapshot,
    );
  }

  Future<void> redo() async {
    await _awaitPendingEndDrawingCommit();
    final snap = await _historyViewModel.redo();
    if (snap == null) return;
    _historyViewModel.scheduleHistoryApply(
      snap,
      HistoryOperationType.redo,
      _applySnapshot,
    );
  }

  void setShapeDrawKind(ShapeKind kind) {
    state = _toolSettingsViewModel.setShapeDrawKind(state, kind);
  }

  void copySelection() {
    final targets = _selectionViewModel.selectedGroupShapes(state);
    if (targets.isEmpty) return;
    state = _shapeOperationsViewModel.copySelection(
      state: state,
      selectedShapes: targets,
    );
  }

  void pasteClipboard() {
    state = _shapeOperationsViewModel.pasteClipboard(
      state: state,
      nextShapeId: _nextShapeId,
    );
    if (state.shapes.length > _shapeCounter) {
      _pushHistory();
    }
  }

  /// Adds an image shape to the canvas, centered and fitted to the artboard.
  void addImageShape(ImagePickResult imageResult) {
    final canvasSize = state.document.size;

    // Fit image within 50% of canvas, preserving aspect ratio
    final imgW = imageResult.originalSize.width;
    final imgH = imageResult.originalSize.height;
    final maxW = canvasSize.width * 0.5;
    final maxH = canvasSize.height * 0.5;
    double scaleToFit = 1.0;
    if (imgW > maxW || imgH > maxH) {
      scaleToFit = math.min(maxW / imgW, maxH / imgH);
    }
    final w = imgW * scaleToFit;
    final h = imgH * scaleToFit;

    // Center on canvas
    final x = (canvasSize.width - w) / 2;
    final y = (canvasSize.height - h) / 2;

    final shape = Shape(
      id: _nextShapeId(),
      kind: ShapeKind.image,
      name: 'Image',
      bounds: Rect.fromLTWH(x, y, w, h),
      imagePath: imageResult.relativePath,
      imageOriginalSize: Size(imgW, imgH),
      strokeColor: const Color(0x00000000),
      strokeWidth: 0,
      opacity: 1.0,
    );

    final updated = [...state.shapes, shape];
    _setShapesAndRebuild(updated, selectedShapeId: shape.id);
    _pushHistory();
  }

  void flipSelectedHorizontal() {
    _flipSelected(horizontal: true);
  }

  void flipSelectedVertical() {
    _flipSelected(vertical: true);
  }

  void _flipSelected({bool horizontal = false, bool vertical = false}) {
    final id = state.selectedShapeId;
    if (id == null) return;
    final idx = state.shapes.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final target = state.shapes[idx];
    final flipped = ShapeTransformer.flip(
      shape: target,
      horizontal: horizontal,
      vertical: vertical,
      flipPivotWithObject: state.pivotFlipWithObject,
    );
    final updated = List<Shape>.from(state.shapes);
    updated[idx] = flipped;
    _setShapesAndRebuild(updated, rebuildQuadTree: false);
    _pushHistory();
  }

  void duplicateSelected() {
    final targets = _selectedGroupShapes();
    if (targets.isEmpty) return;
    final newGroupId = targets.first.groupId != null
        ? _shapeGroupingService.nextGroupId()
        : null;
    final clones = targets
        .map(
          (shape) => shape.copyWith(
            id: _nextShapeId(),
            groupId: newGroupId,
            bounds: shape.bounds?.shift(const Offset(16, 16)),
            points: shape.contours.isNotEmpty
                ? shape.contours.first
                      .map((p) => p + const Offset(16, 16))
                      .toList()
                : shape.points.isNotEmpty
                ? shape.points.map((p) => p + const Offset(16, 16)).toList()
                : shape.points.toList(),
            contours: shape.contours.isNotEmpty
                ? shape.contours
                      .map(
                        (c) => c
                            .map((p) => p + const Offset(16, 16))
                            .toList(growable: false),
                      )
                      .toList(growable: false)
                : null,
            pointPressures: shape.pointPressures?.toList(growable: false),
          ),
        )
        .toList(growable: false);
    final updated = [...state.shapes, ...clones];
    _setShapesAndRebuild(updated, selectedShapeId: clones.last.id);
    _pushHistory();
  }

  void deleteSelected() {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;
    final ids = <String>{};
    for (final index in indices) {
      if (index < 0 || index >= state.shapes.length) continue;
      ids.add(state.shapes[index].id);
    }
    if (ids.isEmpty) return;
    _deleteShapeIdsEverywhere(ids, forceClearSelection: true);
  }

  void deleteSelectedIds() {
    final ids = state.selectedShapeIds;
    if (ids.isEmpty) return;
    _deleteShapeIdsEverywhere(ids.toSet(), forceClearSelection: true);
  }

  void deleteShapes(List<String> ids) {
    if (ids.isEmpty) return;
    _deleteShapeIdsEverywhere(ids.toSet(), forceClearSelection: true);
  }

  void deleteShape(String shapeId) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    _deleteShapeIdsEverywhere(<String>{shapeId}, forceClearSelection: false);
  }

  void duplicateShape(String shapeId) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    final shape = location.shapes[location.index];
    final clone = shape.copyWith(
      id: _nextShapeId(),
      name: _generateCopyName(
        shape.name ?? _shapeKindLabel(shape.kind),
        location.shapes,
      ),
      bounds: shape.bounds?.shift(const Offset(16, 16)),
      points: shape.contours.isNotEmpty
          ? shape.contours.first.map((p) => p + const Offset(16, 16)).toList()
          : shape.points.isNotEmpty
          ? shape.points.map((p) => p + const Offset(16, 16)).toList()
          : shape.points.toList(),
      contours: shape.contours.isNotEmpty
          ? shape.contours
                .map(
                  (c) => c
                      .map((p) => p + const Offset(16, 16))
                      .toList(growable: false),
                )
                .toList(growable: false)
          : null,
      pointPressures: shape.pointPressures?.toList(growable: false),
    );
    final updated = List<Shape>.from(location.shapes)..add(clone);
    _applyLayerShapes(location.layerId, updated);
    selectShape(clone.id);
    _pushHistory();
    _queueAutosave();
  }

  void duplicateGroup(String groupId) {
    final layerId = _findLayerIdForGroup(groupId);
    if (layerId == null) return;
    final layer = state.document.layerById(layerId);
    if (layer == null) return;
    final shapes = layer.frameAt(state.currentFrame).shapes;
    final groupShapes = shapes.where((s) => s.groupId == groupId).toList();
    if (groupShapes.isEmpty) return;

    final newGroupId = _shapeGroupingService.nextGroupId();
    final existingNames = shapes.map((s) => s.name ?? '').toSet();

    final clones = groupShapes.map((shape) {
      final baseName = shape.name ?? _shapeKindLabel(shape.kind);
      return shape.copyWith(
        id: _nextShapeId(),
        groupId: newGroupId,
        name: _generateCopyNameFromSet(baseName, existingNames),
        bounds: shape.bounds?.shift(const Offset(16, 16)),
        points: shape.contours.isNotEmpty
            ? shape.contours.first.map((p) => p + const Offset(16, 16)).toList()
            : shape.points.isNotEmpty
            ? shape.points.map((p) => p + const Offset(16, 16)).toList()
            : shape.points.toList(),
        contours: shape.contours.isNotEmpty
            ? shape.contours
                  .map(
                    (c) => c
                        .map((p) => p + const Offset(16, 16))
                        .toList(growable: false),
                  )
                  .toList(growable: false)
            : null,
        pointPressures: shape.pointPressures?.toList(growable: false),
      );
    }).toList();

    final updated = List<Shape>.from(shapes)..addAll(clones);
    _applyLayerShapes(layerId, updated);

    // Copy group name if exists
    final oldGroupName = state.groupNames[groupId];
    if (oldGroupName != null) {
      final newGroupName = _generateGroupCopyName(oldGroupName);
      state = state.copyWith(
        groupNames: {...state.groupNames, newGroupId: newGroupName},
      );
    }

    _pushHistory();
    _queueAutosave();
  }

  void renameGroup(String groupId, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      // Remove custom name
      final updated = Map<String, String>.from(state.groupNames)
        ..remove(groupId);
      state = state.copyWith(groupNames: updated);
    } else {
      state = state.copyWith(
        groupNames: {...state.groupNames, groupId: trimmed},
      );
    }
    _queueAutosave();
  }

  String _generateCopyName(String baseName, List<Shape> existingShapes) {
    final existingNames = existingShapes.map((s) => s.name ?? '').toSet();
    return _generateCopyNameFromSet(baseName, existingNames);
  }

  String _generateCopyNameFromSet(String baseName, Set<String> existingNames) {
    // Remove existing copy suffix if present
    final copyPattern = RegExp(
      r'^(.+?)(?:\s+copy(?:\s+(\d+))?)?$',
      caseSensitive: false,
    );
    final match = copyPattern.firstMatch(baseName);
    final cleanName = match?.group(1) ?? baseName;

    var candidate = '$cleanName copy';
    if (!existingNames.contains(candidate)) return candidate;

    var counter = 2;
    while (existingNames.contains('$cleanName copy $counter')) {
      counter++;
    }
    return '$cleanName copy $counter';
  }

  String _generateGroupCopyName(String baseName) {
    final existingNames = state.groupNames.values.toSet();
    return _generateCopyNameFromSet(baseName, existingNames);
  }

  String _shapeKindLabel(ShapeKind kind) {
    switch (kind) {
      case ShapeKind.rectangle:
        return 'Rectangle';
      case ShapeKind.ellipse:
        return 'Ellipse';
      case ShapeKind.line:
        return 'Line';
      case ShapeKind.polygon:
        return 'Polygon';
      case ShapeKind.freehand:
        return 'Freehand';
      case ShapeKind.pointPath:
        return 'Point Path';
      case ShapeKind.image:
        return 'Image';
    }
  }

  void renameShape(String shapeId, String newName) {
    final location = _findShapeLocation(shapeId);
    if (location == null) return;
    final normalizedName = newName.trim().isEmpty ? null : newName.trim();
    final updatedDocument = _updateShapeInAllFrames(
      document: state.document,
      layerId: location.layerId,
      shapeId: shapeId,
      transform: (shape) => shape.copyWith(
        name: normalizedName,
        clearName: normalizedName == null,
      ),
    );
    if (identical(updatedDocument, state.document)) return;

    if (location.layerId == state.activeLayerId) {
      final nextShapes = state.shapes
          .map(
            (shape) => shape.id == shapeId
                ? shape.copyWith(
                    name: normalizedName,
                    clearName: normalizedName == null,
                  )
                : shape,
          )
          .toList(growable: false);
      final activeLayer = _resolveLayer(updatedDocument, state.activeLayerId);
      _baseShapes = List<Shape>.unmodifiable(
        activeLayer.frameAt(state.currentFrame).shapes,
      );
      state = state.copyWith(
        document: updatedDocument,
        shapes: List<Shape>.unmodifiable(nextShapes),
      );
    } else {
      state = state.copyWith(document: updatedDocument);
    }
    _queueAutosave();
  }

  /// Checks if all selected shapes are on the same layer.
  /// Returns the layer ID if all shapes are on the same layer, null otherwise.
  String? _checkSelectedShapesSameLayer(List<String> shapeIds) {
    if (shapeIds.isEmpty) return null;

    String? commonLayerId;
    for (final id in shapeIds) {
      final layerId = _findLayerIdForShape(id);
      if (layerId == null) return null; // Shape not found

      if (commonLayerId == null) {
        commonLayerId = layerId;
      } else if (commonLayerId != layerId) {
        return null; // Shapes are on different layers
      }
    }
    return commonLayerId;
  }

  /// Returns true if all selected shapes are on the same layer.
  bool selectedShapesOnSameLayer() {
    return _checkSelectedShapesSameLayer(state.selectedShapeIds) != null;
  }

  /// Merges the selected shapes into a single polygon.
  /// Returns a MergeValidationResult indicating success or failure reason.
  ///
  /// [mode] specifies the path combination operation (default: union).
  Future<MergeValidationResult> mergeSelectedIds({
    MergeMode mode = MergeMode.union,
  }) async {
    final ids = state.selectedShapeIds;
    if (ids.length < 2) {
      return MergeValidationResult.notEnoughShapes;
    }

    // Validate that all shapes are on the same layer
    final layerId = _checkSelectedShapesSameLayer(ids);
    if (layerId == null) {
      return MergeValidationResult.crossLayerMerge;
    }

    // Show processing indicator for 3+ shapes
    if (ids.length >= 3) {
      state = state.copyWith(isProcessingHeavyOperation: true);
    }

    try {
      // Get shapes from the specific layer
      final layer = state.document.layerById(layerId);
      if (layer == null) {
        return MergeValidationResult.layerNotFound;
      }
      final layerShapes = layer.frameAt(state.currentFrame).shapes;

      final result = await _shapeMergeService.mergeAsync(
        shapes: layerShapes,
        selectedIds: ids,
        createId: _nextShapeId,
        strokeScaleWithShape: state.strokeScaleWithShape,
        brushSmoothness: state.activeTool == EditorTool.eraser
            ? state.eraserSettings.smoothness
            : state.brushSettings[state.currentBrush]!.smoothness,
        mode: mode,
      );

      if (result.mergedShapes.isEmpty || result.removedIds.isEmpty) {
        if (ids.length >= 3) {
          state = state.copyWith(isProcessingHeavyOperation: false);
        }
        if (result.hasSkippedShapes) {
          return MergeValidationResult(
            type: MergeResultType.shapesSkipped,
            skipSummary: result.skipSummary,
            skippedCount: result.skippedShapes.length,
          );
        }
        return MergeValidationResult.emptyResult;
      }

      final removeSet = result.removedIds.toSet();
      final updated = <Shape>[];

      // Find the first removed shape's position in z-order.
      // We'll insert the merged shape at this position.
      var firstRemovedIndex = -1;
      var removedCount = 0;

      for (var i = 0; i < layerShapes.length; i++) {
        final shape = layerShapes[i];
        if (removeSet.contains(shape.id)) {
          if (firstRemovedIndex < 0) {
            // Remember where the first merged shape was in z-order
            firstRemovedIndex = updated.length;
          }
          removedCount++;
          continue;
        }
        updated.add(shape);
      }

      if (removedCount < 2) {
        if (ids.length >= 3) {
          state = state.copyWith(isProcessingHeavyOperation: false);
        }
        return MergeValidationResult.emptyResult;
      }

      // Insert at the position where the first removed shape was
      // (which is now the correct index in the updated list)
      final insertIndex = firstRemovedIndex >= 0
          ? math.min(firstRemovedIndex, updated.length)
          : updated.length;
      updated.insertAll(insertIndex, result.mergedShapes);

      // Apply to the specific layer
      _applyLayerShapes(layerId, updated);

      final mergedIds = result.mergedShapes
          .map((shape) => shape.id)
          .toList(growable: false);
      state = state.copyWith(
        selectedShapeId: null,
        selectedShapeIds: mergedIds,
      );
      _pushHistory();

      if (result.hasSkippedShapes) {
        return MergeValidationResult(
          type: MergeResultType.partialSuccess,
          skipSummary: result.skipSummary,
          skippedCount: result.skippedShapes.length,
          mergedCount: result.removedIds.length,
        );
      }
      return MergeValidationResult(
        type: MergeResultType.success,
        mergedCount: result.removedIds.length,
      );
    } finally {
      // Always clear processing state
      if (state.isProcessingHeavyOperation) {
        state = state.copyWith(isProcessingHeavyOperation: false);
      }
    }
  }

  /// Generates a merge preview shape without modifying the actual shapes.
  /// The preview shape is shown as an overlay on the canvas.
  ///
  /// Returns true if preview was generated successfully.
  Future<bool> showMergePreview({MergeMode mode = MergeMode.union}) async {
    final ids = state.selectedShapeIds;
    if (ids.length < 2) return false;

    // Validate that all shapes are on the same layer
    final layerId = _checkSelectedShapesSameLayer(ids);
    if (layerId == null) return false;

    final layer = state.document.layerById(layerId);
    if (layer == null) return false;
    final layerShapes = layer.frameAt(state.currentFrame).shapes;

    final result = await _shapeMergeService.mergeAsync(
      shapes: layerShapes,
      selectedIds: ids,
      createId: () => 'preview-${DateTime.now().millisecondsSinceEpoch}',
      strokeScaleWithShape: state.strokeScaleWithShape,
      brushSmoothness: state.activeTool == EditorTool.eraser
          ? state.eraserSettings.smoothness
          : state.brushSettings[state.currentBrush]!.smoothness,
      mode: mode,
    );

    if (result.mergedShapes.isEmpty) return false;

    // Set the preview shape - it will be rendered as an overlay
    state = state.copyWith(mergePreviewShape: result.mergedShapes.first);
    return true;
  }

  /// Clears the merge preview without applying it.
  void cancelMergePreview() {
    if (!state.isMergePreviewActive) return;
    state = state.copyWith(clearMergePreview: true);
  }

  /// Applies the merge preview and commits the changes.
  Future<MergeValidationResult> applyMergePreview({
    MergeMode mode = MergeMode.union,
  }) async {
    // Clear preview first
    state = state.copyWith(clearMergePreview: true);
    // Then perform the actual merge
    return mergeSelectedIds(mode: mode);
  }

  void groupSelection() {
    final updatedShapes = _shapeGroupingService.groupSelectedShapes(
      allShapes: state.shapes,
      selectedShapeIds: state.selectedShapeIds,
    );
    _setShapesAndRebuild(updatedShapes);
    _pushHistory();
  }

  void ungroupSelection() {
    final beforeShapes = state.shapes;
    final updatedShapes = _shapeGroupingService.ungroupSelectedShapes(
      allShapes: state.shapes,
      selectedShapeIds: state.selectedShapeIds,
    );
    _setShapesAndRebuild(updatedShapes);
    // Propagate group changes across all frames.
    var doc = state.document;
    for (var i = 0; i < updatedShapes.length; i++) {
      final before = i < beforeShapes.length ? beforeShapes[i] : null;
      final after = updatedShapes[i];
      if (before != null &&
          before.id == after.id &&
          before.groupId != after.groupId) {
        doc = _updateShapeInAllFrames(
          document: doc,
          layerId: state.activeLayerId,
          shapeId: after.id,
          transform: (s) => s.copyWith(
            groupId: after.groupId,
            clearGroupId: after.groupId == null,
          ),
        );
      }
    }
    if (!identical(doc, state.document)) {
      state = state.copyWith(document: doc);
    }
    _pushHistory();
  }

  void setCurrentColorPreview(Color color) {
    state = state.copyWith(currentColor: color);
  }

  void setCurrentColor(Color color) {
    setCurrentColorPreview(color);
    recordProjectColor(color);
  }

  List<Color> get projectRecentColors {
    return state.document.recentColors
        .map((value) => Color(value))
        .toList(growable: false);
  }

  void recordProjectColor(Color color) {
    final next = _pushColorToRecent(state.document.recentColors, color);
    if (_sameIntList(next, state.document.recentColors)) {
      return;
    }
    final updatedDocument = state.document.copyWith(
      recentColors: next,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(document: updatedDocument);
    _queueAutosave();
  }

  List<int> _pushColorToRecent(List<int> current, Color color) {
    final argb = color.toARGB32();
    final next = <int>[argb];
    for (final value in current) {
      if (value == argb) continue;
      next.add(value);
      if (next.length >= 10) break;
    }
    return List<int>.unmodifiable(next);
  }

  bool _sameIntList(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Replace shapes by id with the provided transformed copies (no history push).
  void applyTransformedShapes(List<Shape> transformed) {
    if (transformed.isEmpty) return;
    final map = {for (final s in transformed) s.id: s};
    bool changed = false;
    final updated = <Shape>[];
    for (final s in state.shapes) {
      final replacement = map[s.id];
      if (replacement != null) {
        updated.add(replacement);
        changed = true;
      } else {
        updated.add(s);
      }
    }
    if (!changed) return;
    _selectionDirty = true;
    const channels = <ObjectKeyChannel>{
      ObjectKeyChannel.position,
      ObjectKeyChannel.rotation,
      ObjectKeyChannel.scale,
    };
    final persistencePlan = _buildTransformEditPersistencePlan(
      map.keys,
      channels: channels,
    );
    _setShapesAndRebuild(
      updated,
      rebuildQuadTree: false,
      nonPersistentShapeIds: persistencePlan.nonPersistentShapeIds,
    );
    _syncObjectKeyframesForEditedShapeIds(
      map.keys,
      channels: channels,
      transformPersistencePlan: persistencePlan,
    );
  }

  /// Called when starting a rotation session (e.g., grabbing rotation handle).
  /// Captures base child pivot positions for proper rotation propagation.
  void startRotationSession(List<Shape> shapesToRotate) {
    _lastAppliedRotationDelta = 0.0;
    final basePositions = <String, Offset>{};
    final baseRotations = <String, double>{};
    for (final parent in shapesToRotate) {
      final descendants = _hierarchyService.getDescendants(
        parent,
        state.shapes,
      );
      final expanded = _expandSpatialSiblings(descendants);
      for (final child in expanded) {
        final childOrigin = child.localOrigin;
        basePositions[child.id] = _pivotWorldForShape(child, childOrigin);
        baseRotations[child.id] = child.rotation;
      }
    }
    _baseChildPositions = basePositions;
    _baseChildRotations = baseRotations;
  }

  /// Called when ending a rotation session.
  void endRotationSession() {
    _lastAppliedRotationDelta = 0.0;
    _baseChildPositions = const {};
    _baseChildRotations = const {};
  }

  /// Apply rotation to shapes and propagate to their children.
  /// [rotatedShapes] are the shapes that have been rotated.
  /// [totalDelta] is the TOTAL rotation from the start of the session.
  /// [baseShapes] are the original shapes before rotation started.
  void applyRotationWithChildren(
    List<Shape> rotatedShapes,
    double totalDelta,
    List<Shape> baseShapes,
  ) {
    if (rotatedShapes.isEmpty) return;

    // Start with the rotated shapes
    final allUpdated = <Shape>[...rotatedShapes];

    // For each rotated shape, rotate its children's BASE positions by the TOTAL delta
    for (final baseParent in baseShapes) {
      final parentPivotWorld =
          baseParent.transform.position +
          baseParent.localOrigin +
          baseParent.transform.pivot;

      final descendants = _hierarchyService.getDescendants(
        baseParent,
        state.shapes,
      );
      final expanded = _expandSpatialSiblings(descendants);
      for (final child in expanded) {
        final basePivotWorld = _baseChildPositions[child.id];
        if (basePivotWorld == null) continue;
        final baseRotation = _baseChildRotations[child.id] ?? child.rotation;

        // Rotate child's BASE pivot around parent's pivot by the TOTAL delta
        final relativePos = basePivotWorld - parentPivotWorld;
        final rotatedPos = _rotatePoint(relativePos, totalDelta);
        final newPivotWorld = parentPivotWorld + rotatedPos;
        final childLocalPivot = child.localOrigin + child.transform.pivot;
        final newTranslation = newPivotWorld - childLocalPivot;

        allUpdated.add(
          child.copyWith(
            translation: newTranslation,
            rotation: baseRotation + totalDelta,
          ),
        );
      }
    }

    applyTransformedShapes(allUpdated);
  }

  void togglePanMode() {
    state = _toolToggles.togglePanMode(state);
  }

  void setPanMode(bool enabled) {
    if (state.isPanMode == enabled) return;
    state = state.copyWith(isPanMode: enabled);
  }

  void setBrushType(BrushType brush) {
    state = state.copyWith(currentBrush: brush);
  }

  void setBrushThickness(double value) {
    final currentSettings = state.brushSettings[state.currentBrush]!;
    final updatedSettings = currentSettings.copyWith(
      thickness: value.clamp(0.5, 300),
    );
    final newBrushSettings = Map<BrushType, BrushSettings>.from(
      state.brushSettings,
    );
    newBrushSettings[state.currentBrush] = updatedSettings;
    state = state.copyWith(brushSettings: newBrushSettings);
  }

  void setBrushOpacity(double value) {
    final currentSettings = state.brushSettings[state.currentBrush]!;
    final updatedSettings = currentSettings.copyWith(
      opacity: value.clamp(0.05, 1.0),
    );
    final newBrushSettings = Map<BrushType, BrushSettings>.from(
      state.brushSettings,
    );
    newBrushSettings[state.currentBrush] = updatedSettings;
    state = state.copyWith(brushSettings: newBrushSettings);
  }

  void setBrushSmoothness(double value) {
    final currentSettings = state.brushSettings[state.currentBrush]!;
    final updatedSettings = currentSettings.copyWith(
      smoothness: value.clamp(0.0, 1.0),
    );
    final newBrushSettings = Map<BrushType, BrushSettings>.from(
      state.brushSettings,
    );
    newBrushSettings[state.currentBrush] = updatedSettings;
    state = state.copyWith(brushSettings: newBrushSettings);
  }

  void setEraserThickness(double value) {
    final updatedSettings = state.eraserSettings.copyWith(
      thickness: value.clamp(0.5, 300),
    );
    state = state.copyWith(eraserSettings: updatedSettings);
  }

  void setEraserOpacity(double value) {
    final updatedSettings = state.eraserSettings.copyWith(
      opacity: value.clamp(0.05, 1.0),
    );
    state = state.copyWith(eraserSettings: updatedSettings);
  }

  void setEraserSmoothness(double value) {
    final updatedSettings = state.eraserSettings.copyWith(
      smoothness: value.clamp(0.0, 1.0),
    );
    state = state.copyWith(eraserSettings: updatedSettings);
  }

  void togglePalmRejection() {
    state = state.copyWith(palmRejectionEnabled: !state.palmRejectionEnabled);
  }

  void toggleGrouping() {
    if (state.groupingEnabled) {
      state = state.copyWith(groupingEnabled: false, currentGroupId: null);
    } else {
      state = state.copyWith(
        groupingEnabled: true,
        currentGroupId: _shapeGroupingService.nextGroupId(),
      );
    }
  }

  void toggleTransformGroupAsOne() {
    state = state.copyWith(transformGroupAsOne: !state.transformGroupAsOne);
  }

  void setShapeFillColor(Color? color) {
    state = state.copyWith(shapeFillColor: color);
  }

  void updateSelectedTransform({
    double? rotation,
    double? scale,
    bool addToHistory = false,
  }) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;
    final transformedIds = <String>{};
    final updatedShapes = List<Shape>.from(state.shapes);
    for (final idx in indices) {
      final target = state.shapes[idx];
      if (target.kind == ShapeKind.line && target.points.length < 2) continue;
      transformedIds.add(target.id);
      updatedShapes[idx] = ShapeTransformer.applyTransform(
        shape: target,
        rotation: rotation,
        scale: scale,
      );
    }
    final channels = <ObjectKeyChannel>{};
    if (rotation != null) {
      channels.add(ObjectKeyChannel.rotation);
    }
    if (scale != null) {
      channels.add(ObjectKeyChannel.scale);
    }
    final persistencePlan = _buildTransformEditPersistencePlan(
      transformedIds,
      channels: channels,
    );
    _setShapesAndRebuild(
      updatedShapes,
      rebuildQuadTree: false,
      nonPersistentShapeIds: persistencePlan.nonPersistentShapeIds,
    );
    if (channels.isNotEmpty) {
      _syncObjectKeyframesForEditedShapeIds(
        transformedIds,
        channels: channels,
        transformPersistencePlan: persistencePlan,
      );
    }
    if (addToHistory) {
      _pushHistory();
    }
  }

  void scaleSelectedGeometry({
    Rect? baseBounds,
    List<Offset>? basePoints,
    required double scaleX,
    required double scaleY,
    String? shapeId,
  }) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;
    _selectionDirty = true;
    final transformedIds = <String>{};
    final clampedScaleX = scaleX.clamp(0.05, 10.0);
    final clampedScaleY = scaleY.clamp(0.05, 10.0);

    final updatedShapes = List<Shape>.from(state.shapes);
    for (final idx in indices) {
      final target = state.shapes[idx];
      transformedIds.add(target.id);
      final usesBounds =
          target.kind == ShapeKind.rectangle ||
          target.kind == ShapeKind.ellipse;
      // Use provided base bounds/points only when scaling a single shape; otherwise use each shape's own geometry.
      final useShared = indices.length == 1;
      final bounds =
          (useShared ? baseBounds : null) ??
          target.bounds ??
          _shapeBounds(target);

      Shape updated = target;
      if (usesBounds && bounds != null) {
        final center = bounds.center;
        final halfW = bounds.width / 2 * clampedScaleX;
        final halfH = bounds.height / 2 * clampedScaleY;
        final newRect = Rect.fromLTRB(
          center.dx - halfW,
          center.dy - halfH,
          center.dx + halfW,
          center.dy + halfH,
        );
        updated = target.copyWith(bounds: newRect);
      } else if (target.contours.isNotEmpty) {
        final boundsFromPoints =
            (useShared ? baseBounds : null) ?? _shapeBounds(target);
        final contourPoints = target.contours
            .map((c) => c.toList(growable: false))
            .toList(growable: false);
        if (contourPoints.isNotEmpty && contourPoints.first.isNotEmpty) {
          final center = boundsFromPoints?.center ?? contourPoints.first.first;
          final scaledContours = contourPoints
              .map(
                (c) => c
                    .map(
                      (p) => Offset(
                        center.dx + (p.dx - center.dx) * clampedScaleX,
                        center.dy + (p.dy - center.dy) * clampedScaleY,
                      ),
                    )
                    .toList(growable: false),
              )
              .toList(growable: false);
          updated = target.copyWith(
            points: scaledContours.first,
            contours: scaledContours,
            bounds: null,
            pointPressures: _preservePointPressures(
              target,
              scaledContours.first,
            ),
          );
        }
      } else {
        final points =
            (useShared ? basePoints : null) ?? target.points.toList();
        if (points.isNotEmpty) {
          final boundsFromPoints =
              (useShared ? baseBounds : null) ?? _shapeBounds(target);
          final center = boundsFromPoints?.center ?? points.first;
          final scaledPoints = points
              .map(
                (p) => Offset(
                  center.dx + (p.dx - center.dx) * clampedScaleX,
                  center.dy + (p.dy - center.dy) * clampedScaleY,
                ),
              )
              .toList(growable: false);
          updated = target.copyWith(
            points: scaledPoints,
            bounds: null,
            pointPressures: _preservePointPressures(target, scaledPoints),
          );
        }
      }
      updatedShapes[idx] = updated;
    }

    const channels = <ObjectKeyChannel>{
      ObjectKeyChannel.position,
      ObjectKeyChannel.scale,
    };
    final persistencePlan = _buildTransformEditPersistencePlan(
      transformedIds,
      channels: channels,
    );

    _setShapesAndRebuild(
      updatedShapes,
      rebuildQuadTree: false,
      nonPersistentShapeIds: persistencePlan.nonPersistentShapeIds,
    );
    _syncObjectKeyframesForEditedShapeIds(
      transformedIds,
      channels: channels,
      transformPersistencePlan: persistencePlan,
    );
  }

  /// Apply rotation around a common center using a snapshot of shapes.
  void applyRotationFromSnapshot({
    required List<Shape> baseShapes,
    required Offset center,
    required double deltaAngle,
  }) {
    if (baseShapes.isEmpty || deltaAngle == 0.0) return;
    _selectionDirty = true;
    final updated = List<Shape>.from(state.shapes);
    final ids = baseShapes.map((s) => s.id).toSet();
    for (var i = 0; i < updated.length; i++) {
      final current = updated[i];
      if (!ids.contains(current.id)) continue;
      final base = baseShapes.firstWhere((s) => s.id == current.id);
      updated[i] = _rotateShapeFromCenter(base, center, deltaAngle);
    }
    const channels = <ObjectKeyChannel>{
      ObjectKeyChannel.position,
      ObjectKeyChannel.rotation,
    };
    final persistencePlan = _buildTransformEditPersistencePlan(
      ids,
      channels: channels,
    );
    _setShapesAndRebuild(
      updated,
      rebuildQuadTree: false,
      nonPersistentShapeIds: persistencePlan.nonPersistentShapeIds,
    );
    _syncObjectKeyframesForEditedShapeIds(
      ids,
      channels: channels,
      transformPersistencePlan: persistencePlan,
    );
  }

  /// Apply scaling to the current selection using a snapshot of base shapes and a common center.
  void applyScaleFromSnapshot({
    required List<Shape> baseShapes,
    required Offset center,
    required double scaleX,
    required double scaleY,
  }) {
    if (baseShapes.isEmpty) return;
    _selectionDirty = true;
    final sx = scaleX.clamp(0.05, 100.0);
    final sy = scaleY.clamp(0.05, 100.0);
    final updated = List<Shape>.from(state.shapes);
    final ids = baseShapes.map((s) => s.id).toSet();
    for (var i = 0; i < updated.length; i++) {
      final current = updated[i];
      if (!ids.contains(current.id)) continue;
      final base = baseShapes.firstWhere((s) => s.id == current.id);
      updated[i] = _scaleShapeFromCenter(
        base,
        center,
        sx,
        sy,
      ).copyWith(scaleX: base.scaleX, scaleY: base.scaleY);
    }
    const channels = <ObjectKeyChannel>{
      ObjectKeyChannel.position,
      ObjectKeyChannel.scale,
    };
    final persistencePlan = _buildTransformEditPersistencePlan(
      ids,
      channels: channels,
    );
    _setShapesAndRebuild(
      updated,
      rebuildQuadTree: false,
      nonPersistentShapeIds: persistencePlan.nonPersistentShapeIds,
    );
    _syncObjectKeyframesForEditedShapeIds(
      ids,
      channels: channels,
      transformPersistencePlan: persistencePlan,
    );
  }

  Shape _scaleShapeFromCenter(
    Shape base,
    Offset center,
    double scaleX,
    double scaleY,
  ) {
    return _transformService.scaleShapeFromCenter(base, center, scaleX, scaleY);
  }

  Shape _rotateShapeFromCenter(Shape base, Offset center, double deltaAngle) {
    return _transformService.rotateShapeFromCenter(base, center, deltaAngle);
  }

  void updateSelectedStroke({
    double? strokeWidth,
    Color? strokeColor,
    bool addToHistory = true,
  }) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;

    final updatedShapes = List<Shape>.from(state.shapes);
    final editedIds = <String>{};
    for (final index in indices) {
      final target = state.shapes[index];
      editedIds.add(target.id);
      updatedShapes[index] = target.copyWith(
        strokeWidth: strokeWidth ?? target.strokeWidth,
        strokeColor: strokeColor ?? target.strokeColor,
      );
    }

    if (state.styleEditScope.isGlobal) {
      _applyGlobalStylePatch(
        shapeIds: editedIds,
        patch: ShapeStylePatch(
          strokeWidth: strokeWidth,
          strokeColor: strokeColor,
        ),
        addToHistory: addToHistory,
      );
      return;
    }

    _setShapesAndRebuild(
      updatedShapes,
      rebuildQuadTree: false,
      nonPersistentShapeIds: _nonPersistentTransformShapeIds(editedIds),
    );
    final channels = <ObjectKeyChannel>{};
    if (strokeWidth != null) {
      channels.add(ObjectKeyChannel.strokeWidth);
    }
    if (strokeColor != null) {
      channels.add(ObjectKeyChannel.strokeColor);
    }
    if (channels.isNotEmpty) {
      _syncObjectKeyframesForEditedShapeIds(editedIds, channels: channels);
    }
    if (addToHistory) {
      _pushHistoryDeferred();
    }
  }

  void updateSelectedOpacity(double opacity, {bool addToHistory = true}) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;

    final clampedOpacity = opacity.clamp(0.0, 1.0);
    final updatedShapes = List<Shape>.from(state.shapes);
    final editedIds = <String>{};
    for (final index in indices) {
      final target = state.shapes[index];
      editedIds.add(target.id);
      updatedShapes[index] = target.copyWith(opacity: clampedOpacity);
    }

    if (state.styleEditScope.isGlobal) {
      _applyGlobalStylePatch(
        shapeIds: editedIds,
        patch: ShapeStylePatch(opacity: clampedOpacity),
        addToHistory: addToHistory,
      );
      return;
    }

    _setShapesAndRebuild(
      updatedShapes,
      rebuildQuadTree: false,
      nonPersistentShapeIds: _nonPersistentTransformShapeIds(editedIds),
    );
    _syncObjectKeyframesForEditedShapeIds(
      editedIds,
      channels: const <ObjectKeyChannel>{ObjectKeyChannel.opacity},
    );
    if (addToHistory) {
      _pushHistoryDeferred();
    }
  }

  void updateSelectedFill(Color? fillColor, {bool addToHistory = true}) {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return;

    final updatedShapes = List<Shape>.from(state.shapes);
    final editedIds = <String>{};
    for (final index in indices) {
      final target = state.shapes[index];
      editedIds.add(target.id);
      updatedShapes[index] = target.copyWith(fillColor: fillColor);
    }

    if (state.styleEditScope.isGlobal) {
      _applyGlobalStylePatch(
        shapeIds: editedIds,
        patch: ShapeStylePatch(
          fillColor: fillColor,
          clearFillColor: fillColor == null,
        ),
        addToHistory: addToHistory,
      );
      return;
    }

    _setShapesAndRebuild(
      updatedShapes,
      rebuildQuadTree: false,
      nonPersistentShapeIds: _nonPersistentTransformShapeIds(editedIds),
    );
    _syncObjectKeyframesForEditedShapeIds(
      editedIds,
      channels: const <ObjectKeyChannel>{ObjectKeyChannel.fillColor},
    );
    if (addToHistory) {
      _pushHistoryDeferred();
    }
  }

  /// Sets or clears the shape raster paint path metadata for the given shape.
  ///
  /// Returns `true` when the shape was found and updated.
  bool setShapeRasterPaintPath(
    String shapeId,
    String? relativePath, {
    bool addToHistory = true,
  }) {
    final index = state.shapes.indexWhere((shape) => shape.id == shapeId);
    if (index == -1) return false;

    final target = state.shapes[index];
    final nextMetadata = <String, dynamic>{};
    if (target.metadata != null) {
      nextMetadata.addAll(target.metadata!);
    }

    if (relativePath == null || relativePath.isEmpty) {
      nextMetadata.remove(kShapeRasterPaintPathKey);
    } else {
      nextMetadata[kShapeRasterPaintPathKey] = relativePath;
    }

    final updatedShape = nextMetadata.isEmpty
        ? target.copyWith(clearMetadata: true)
        : target.copyWith(metadata: nextMetadata);
    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updatedShape;
    _setShapesAndRebuild(
      updatedShapes,
      rebuildQuadTree: false,
      propagateAddedShapes: false,
    );

    final propagatedDocument = _propagateShapeRasterPathToLayerFrames(
      document: state.document,
      layerId: state.activeLayerId,
      shapeId: shapeId,
      relativePath: relativePath,
    );
    if (!identical(propagatedDocument, state.document)) {
      state = state.copyWith(document: propagatedDocument);
    }
    if (addToHistory) {
      _pushHistoryDeferred();
    }
    return true;
  }

  CanvasDocument _propagateShapeRasterPathToLayerFrames({
    required CanvasDocument document,
    required String layerId,
    required String shapeId,
    required String? relativePath,
  }) {
    final layer = document.layerById(layerId);
    if (layer == null || layer.frames.isEmpty) return document;

    final updatedFrames = Map<int, CanvasFrame>.from(layer.frames);
    var changed = false;
    for (final entry in layer.frames.entries) {
      final frame = entry.value;
      var frameChanged = false;
      final nextShapes = frame.shapes
          .map((shape) {
            if (shape.id != shapeId) return shape;
            final updated = _shapeWithRasterPath(shape, relativePath);
            if (!identical(updated, shape)) {
              frameChanged = true;
            }
            return updated;
          })
          .toList(growable: false);
      if (!frameChanged) continue;
      updatedFrames[entry.key] = frame.copyWith(
        shapes: List<Shape>.unmodifiable(nextShapes),
      );
      changed = true;
    }

    if (!changed) return document;
    final nextLayer = layer.copyWith(frames: updatedFrames);
    return document.upsertLayer(nextLayer).copyWith(updatedAt: DateTime.now());
  }

  Shape _shapeWithRasterPath(Shape shape, String? relativePath) {
    final nextMetadata = <String, dynamic>{};
    final currentMetadata = shape.metadata;
    if (currentMetadata != null) {
      nextMetadata.addAll(currentMetadata);
    }

    final normalizedPath = (relativePath == null || relativePath.isEmpty)
        ? null
        : relativePath;
    if (normalizedPath == null) {
      if (!nextMetadata.containsKey(kShapeRasterPaintPathKey)) {
        return shape;
      }
      nextMetadata.remove(kShapeRasterPaintPathKey);
    } else {
      final current = nextMetadata[kShapeRasterPaintPathKey];
      if (current == normalizedPath) {
        return shape;
      }
      nextMetadata[kShapeRasterPaintPathKey] = normalizedPath;
    }

    return nextMetadata.isEmpty
        ? shape.copyWith(clearMetadata: true)
        : shape.copyWith(metadata: nextMetadata);
  }

  /// Applies fill color to a shape by ID (used by fill tool).
  /// If the shape already has the same fill color, removes the fill (toggle).
  /// Returns true if a shape was filled, false otherwise.
  bool applyFillToShapeById(String shapeId, Color fillColor) {
    final index = state.shapes.indexWhere((s) => s.id == shapeId);
    if (index == -1) return false;

    final shape = state.shapes[index];

    // Check if shape can be filled (closed shapes only)
    if (!_canFillShape(shape)) return false;

    // Toggle: if same color, remove fill; otherwise apply new color
    final newFillColor = shape.fillColor == fillColor ? null : fillColor;

    if (state.styleEditScope.isGlobal) {
      _applyGlobalStylePatch(
        shapeIds: <String>{shapeId},
        patch: ShapeStylePatch(
          fillColor: newFillColor,
          clearFillColor: newFillColor == null,
        ),
      );
      return true;
    }

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = shape.copyWith(fillColor: newFillColor);
    _setShapesAndRebuild(
      updatedShapes,
      rebuildQuadTree: false,
      nonPersistentShapeIds: _nonPersistentTransformShapeIds(<String>[shapeId]),
    );
    _syncObjectKeyframesForEditedShapeIds(
      <String>[shapeId],
      channels: const <ObjectKeyChannel>{ObjectKeyChannel.fillColor},
    );
    _pushHistory();
    return true;
  }

  /// Checks if a shape can be filled.
  bool _canFillShape(Shape shape) {
    switch (shape.kind) {
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
      case ShapeKind.polygon:
        return true;
      case ShapeKind.freehand:
        // Freehand can be filled if it's closed
        return shape.isClosed || _isFreehandClosedByProximity(shape);
      case ShapeKind.pointPath:
        // Point path can be filled if it's closed
        return shape.isClosed;
      case ShapeKind.line:
      case ShapeKind.image:
        return false;
    }
  }

  /// Checks if a freehand shape is closed by endpoint proximity.
  bool _isFreehandClosedByProximity(Shape shape, {double threshold = 6.0}) {
    if (shape.points.length < 3) return false;
    final first = shape.points.first;
    final last = shape.points.last;
    return (first - last).distance <= threshold;
  }

  void updateSelectedBounds({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    final targetId = state.selectedShapeId;
    if (targetId == null) return;
    final index = state.shapes.indexWhere((s) => s.id == targetId);
    if (index == -1) return;

    final target = state.shapes[index];
    final existingBounds = target.bounds ?? _shapeBounds(target);
    if (existingBounds == null) return;

    final newWidth = (width ?? existingBounds.width)
        .clamp(0, double.infinity)
        .toDouble();
    final newHeight = (height ?? existingBounds.height)
        .clamp(0, double.infinity)
        .toDouble();
    final newRect = Rect.fromLTWH(
      x ?? existingBounds.left,
      y ?? existingBounds.top,
      newWidth,
      newHeight,
    );

    Shape updated;
    if (target.bounds != null) {
      updated = target.copyWith(bounds: newRect);
    } else {
      final delta = newRect.topLeft - existingBounds.topLeft;
      if (target.contours.isNotEmpty) {
        final shiftedContours = target.contours
            .map((c) => c.map((p) => p + delta).toList(growable: false))
            .toList(growable: false);
        updated = target.copyWith(
          points: shiftedContours.first,
          contours: shiftedContours,
          pointPressures: _preservePointPressures(
            target,
            shiftedContours.first,
          ),
        );
      } else {
        final shiftedPoints = target.points
            .map((p) => p + delta)
            .toList(growable: false);
        updated = target.copyWith(
          points: shiftedPoints,
          pointPressures: _preservePointPressures(target, shiftedPoints),
        );
      }
    }

    final updatedShapes = List<Shape>.from(state.shapes);
    updatedShapes[index] = updated;
    const channels = <ObjectKeyChannel>{
      ObjectKeyChannel.position,
      ObjectKeyChannel.scale,
    };
    final persistencePlan = _buildTransformEditPersistencePlan(<String>[
      target.id,
    ], channels: channels);
    _setShapesAndRebuild(
      updatedShapes,
      nonPersistentShapeIds: persistencePlan.nonPersistentShapeIds,
    );
    _syncObjectKeyframesForEditedShapeIds(
      <String>[target.id],
      channels: channels,
      transformPersistencePlan: persistencePlan,
    );
    _pushHistoryDeferred();
  }

  String _nextLayerId() {
    _layerCounter += 1;
    return 'layer-$_layerCounter';
  }

  String _nextShapeId() {
    _shapeCounter += 1;
    return 'shape-$_shapeCounter';
  }

  String _nextSpatialId() {
    _spatialCounter += 1;
    return 'spatial-$_spatialCounter';
  }

  List<int> _selectedGroupIndices() {
    return _selectionUtils.selectedGroupIndices(
      state.shapes,
      state.selectedShapeId,
    );
  }

  List<Shape> _selectedGroupShapes() {
    return _selectionUtils.selectedGroupShapes(
      state.shapes,
      state.selectedShapeId,
    );
  }

  List<Shape> _expandSpatialSiblings(Iterable<Shape> shapes) {
    final spatialIds = <String>{};
    for (final shape in shapes) {
      final spatialId = shape.spatialObjectId;
      if (spatialId != null) {
        spatialIds.add(spatialId);
      }
    }
    if (spatialIds.isEmpty) {
      return shapes.toList(growable: false);
    }
    final expanded = <String, Shape>{};
    for (final shape in shapes) {
      expanded[shape.id] = shape;
    }
    for (final shape in state.shapes) {
      final spatialId = shape.spatialObjectId;
      if (spatialId != null && spatialIds.contains(spatialId)) {
        expanded[shape.id] = shape;
      }
    }
    return expanded.values.toList(growable: false);
  }

  Rect? _selectionBoundsFor(List<Shape> shapes) {
    Rect? bounds;
    for (final shape in shapes) {
      final shapeBounds = shape.worldBounds ?? shape.localBounds;
      if (shapeBounds == null) continue;
      bounds = bounds == null
          ? shapeBounds
          : bounds.expandToInclude(shapeBounds);
    }
    return bounds;
  }

  Offset _clampDeltaToCanvas(Offset delta, Rect? selectionBounds) {
    if (selectionBounds == null) return delta;
    final canvasSize = state.document.size;
    final canvasRect = Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    var dx = delta.dx;
    var dy = delta.dy;

    if (selectionBounds.left + dx < canvasRect.left) {
      dx = canvasRect.left - selectionBounds.left;
    } else if (selectionBounds.right + dx > canvasRect.right) {
      dx = canvasRect.right - selectionBounds.right;
    }

    if (selectionBounds.top + dy < canvasRect.top) {
      dy = canvasRect.top - selectionBounds.top;
    } else if (selectionBounds.bottom + dy > canvasRect.bottom) {
      dy = canvasRect.bottom - selectionBounds.bottom;
    }

    return Offset(dx, dy);
  }

  List<double>? _preservePointPressures(Shape shape, List<Offset>? points) {
    final pressures = shape.pointPressures;
    if (pressures == null || points == null) return null;
    if (pressures.length != points.length) return null;
    return pressures.toList(growable: false);
  }

  void startDrawing(
    Offset point, {
    Duration timeStamp = Duration.zero,
    double pressure = 1.0,
  }) {
    final result = _drawingViewModel.startDrawing(
      state,
      point,
      timeStamp: timeStamp,
      pressure: pressure,
    );
    state = result.state;
  }

  void continueDrawing(
    Offset point, {
    Duration timeStamp = Duration.zero,
    double pressure = 1.0,
  }) {
    final result = _drawingViewModel.continueDrawing(
      state,
      point,
      timeStamp: timeStamp,
      pressure: pressure,
    );
    state = result.state;
  }

  Future<void> endDrawing() {
    final pending = _pendingEndDrawingCommit;
    if (pending != null) {
      return pending;
    }
    final operation = _commitEndDrawing();
    _pendingEndDrawingCommit = operation;
    return operation.whenComplete(() {
      if (identical(_pendingEndDrawingCommit, operation)) {
        _pendingEndDrawingCommit = null;
      }
    });
  }

  Future<void> _commitEndDrawing() async {
    final result = await _drawingViewModel.endDrawing(
      state,
      _nextShapeId,
      _document.quadTree,
    );
    state = result.state;

    if (result.newShapes.isNotEmpty || result.idsToDelete.isNotEmpty) {
      final previousShapes = state.shapes;
      var newShapes = result.newShapes;
      String? spatialId;
      if (state.isSpatialDrawMode) {
        spatialId = _ensureActiveSpatialObjectId();
        if (spatialId != null) {
          newShapes = newShapes
              .map((shape) => shape.copyWith(spatialObjectId: spatialId))
              .toList(growable: false);
        }
      }

      // Handle erased shapes: replace in-place if same ID, otherwise remove
      final idsToRemove = result.idsToDelete.toSet();
      final replacementById = {for (final s in newShapes) s.id: s};
      final existingIds = state.shapes.map((s) => s.id).toSet();

      final updatedShapes = <Shape>[];
      for (final shape in state.shapes) {
        if (replacementById.containsKey(shape.id)) {
          // Replace in place - keeps position in layer tree
          updatedShapes.add(replacementById[shape.id]!);
        } else if (!idsToRemove.contains(shape.id)) {
          // Keep unchanged shapes
          updatedShapes.add(shape);
        }
        // Shapes in idsToRemove without replacement are fully erased (skipped)
      }

      // Add truly new shapes (not replacements) at the end
      for (final shape in newShapes) {
        if (!existingIds.contains(shape.id)) {
          updatedShapes.add(shape);
        }
      }

      _syncSpatialObjectsAfterShapeChanges(
        previousShapes: previousShapes,
        nextShapes: updatedShapes,
        changedShapes: newShapes,
        removedIds: idsToRemove,
      );

      _setShapesAndRebuild(
        updatedShapes,
        selectedShapeId: state.isSpatialDrawMode ? null : result.selectShapeId,
        clearSelection: state.isSpatialDrawMode ? true : result.clearSelection,
      );
      if (spatialId != null) {
        _attachShapesToSpatial(spatialId, newShapes);
      }
      if (result.newCurrentGroupId != null) {
        state = state.copyWith(currentGroupId: result.newCurrentGroupId);
      }
      _pushHistory();
      return;
    }
  }

  Future<void> _awaitPendingEndDrawingCommit() async {
    final pending = _pendingEndDrawingCommit;
    if (pending == null) return;
    await pending;
  }

  void _syncSpatialObjectsAfterShapeChanges({
    required List<Shape> previousShapes,
    required List<Shape> nextShapes,
    required List<Shape> changedShapes,
    required Set<String> removedIds,
  }) {
    if (state.spatialObjects.isEmpty) return;
    if (changedShapes.isEmpty && removedIds.isEmpty) return;

    final changedIds = <String>{
      for (final shape in changedShapes) shape.id,
      ...removedIds,
    };
    final changedSpatialIds = <String>{};

    for (final shape in changedShapes) {
      final spatialId = shape.spatialObjectId;
      if (spatialId != null) {
        changedSpatialIds.add(spatialId);
      }
    }
    for (final shape in previousShapes) {
      if (!changedIds.contains(shape.id)) continue;
      final spatialId = shape.spatialObjectId;
      if (spatialId != null) {
        changedSpatialIds.add(spatialId);
      }
    }

    if (changedSpatialIds.isEmpty) return;

    final nextById = <String, Shape>{
      for (final shape in nextShapes) shape.id: shape,
    };
    var didChangeSpatial = false;
    final updatedSpatialObjects = <SpatialObject>[];

    for (final spatial in state.spatialObjects) {
      if (!changedSpatialIds.contains(spatial.id)) {
        updatedSpatialObjects.add(spatial);
        continue;
      }

      final nextChildren = <String>[...spatial.childShapeIds];
      nextChildren.removeWhere((id) {
        if (removedIds.contains(id)) return true;
        final next = nextById[id];
        return next != null && next.spatialObjectId != spatial.id;
      });

      for (final shape in nextShapes) {
        if (shape.spatialObjectId == spatial.id &&
            !nextChildren.contains(shape.id)) {
          nextChildren.add(shape.id);
        }
      }

      final deduped = <String>[];
      final seen = <String>{};
      for (final id in nextChildren) {
        if (seen.add(id)) {
          deduped.add(id);
        }
      }

      if (_listEquals(spatial.childShapeIds, deduped)) {
        updatedSpatialObjects.add(spatial);
      } else {
        didChangeSpatial = true;
        updatedSpatialObjects.add(spatial.copyWith(childShapeIds: deduped));
      }
    }

    if (didChangeSpatial) {
      state = state.copyWith(spatialObjects: updatedSpatialObjects);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Abort an in-progress stroke without committing it (e.g., multitouch).
  void cancelDrawing() {
    final result = _drawingViewModel.cancelDrawing(state);
    if (result.state != null) {
      state = result.state!;
    }
  }

  /// Abort an in-progress shape draw and discard the provisional shape.
  void cancelShapeDrawing() {
    final result = _drawingViewModel.cancelShapeDrawing(state);
    if (result.success) {
      _setShapesAndRebuild(
        result.state.shapes,
        clearSelection: true,
        rebuildQuadTree: result.needsQuadTreeRebuild,
        propagateAddedShapes: false,
      );
    }
    _shapeDrawStartShapeIds = null;
  }

  void startShapeDrawing(Offset point) {
    _shapeDrawStartShapeIds = null;
    final shapeIdsBeforeDraw = state.shapes.map((shape) => shape.id).toSet();
    final result = _drawingViewModel.startShapeDrawing(
      state,
      point,
      _nextShapeId,
    );
    if (result.success) {
      _shapeDrawStartShapeIds = shapeIdsBeforeDraw;
      _setShapesAndRebuild(
        result.state.shapes,
        selectedShapeId: result.selectedShapeId,
        propagateAddedShapes: false,
      );
    }
  }

  void updateShapeDrawing(Offset point) {
    final updatedState = _drawingViewModel.updateShapeDrawing(state, point);
    if (updatedState != null) {
      _setShapesAndRebuild(
        updatedState.shapes,
        rebuildQuadTree: false,
        propagateAddedShapes: false,
      );
    }
  }

  void finishShapeDrawing() {
    final shapeIdsBeforeDraw = _shapeDrawStartShapeIds;
    final result = _drawingViewModel.finishShapeDrawing(state);
    _setShapesAndRebuild(
      result.state.shapes,
      rebuildQuadTree: result.needsQuadTreeRebuild,
      propagateAddedShapes: false,
    );
    if (shapeIdsBeforeDraw != null) {
      final previousShapes = state.shapes
          .where((shape) => shapeIdsBeforeDraw.contains(shape.id))
          .toList(growable: false);
      final propagatedDocument = _propagateAddedShapesToAllFrames(
        document: state.document,
        layerId: state.activeLayerId,
        currentFrame: state.currentFrame,
        previousShapes: previousShapes,
        currentShapes: state.shapes,
      );
      if (!identical(propagatedDocument, state.document)) {
        state = state.copyWith(document: propagatedDocument);
      }
    }
    _shapeDrawStartShapeIds = null;
    _pushHistory();
  }

  void moveSelectedBy(Offset delta) {
    if (delta == Offset.zero) return;
    final shapesToMove = _selectedMoveShapeIds();
    _moveShapesByIds(shapesToMove, delta);
  }

  Set<String> _selectedMoveShapeIds() {
    final indices = _selectedGroupIndices();
    if (indices.isEmpty) return const <String>{};
    final shapesToMove = <String>{};
    for (final index in indices) {
      final target = state.shapes[index];
      shapesToMove.add(target.id);
      final descendants = _hierarchyService.getDescendants(
        target,
        state.shapes,
      );
      for (final desc in descendants) {
        shapesToMove.add(desc.id);
      }
    }
    return shapesToMove;
  }

  void _moveShapesByIds(Set<String> shapeIds, Offset delta) {
    if (delta == Offset.zero || shapeIds.isEmpty) return;
    var changed = false;
    final updated = List<Shape>.from(state.shapes);
    for (var i = 0; i < updated.length; i++) {
      if (shapeIds.contains(updated[i].id)) {
        updated[i] = _translateShape(updated[i], delta);
        changed = true;
      }
    }
    if (!changed) return;
    _selectionDirty = true;
    const channels = <ObjectKeyChannel>{ObjectKeyChannel.position};
    final persistencePlan = _buildTransformEditPersistencePlan(
      shapeIds,
      channels: channels,
    );
    _setShapesAndRebuild(
      updated,
      rebuildQuadTree: false,
      nonPersistentShapeIds: persistencePlan.nonPersistentShapeIds,
    );
    _syncObjectKeyframesForEditedShapeIds(
      shapeIds,
      channels: channels,
      transformPersistencePlan: persistencePlan,
    );
  }

  void selectAtPoint(Offset point, {required double viewportScale}) {
    final change = _selectionService.selectAtPoint(
      _selectionContext(),
      point,
      _document.quadTree,
      viewportScale: viewportScale,
    );
    state = state.copyWith(
      selectedShapeId: change.selectedShapeId,
      selectedShapeIds: change.selectedShapeIds,
      clearSelection: change.clearSelection,
    );
    _rememberObjectTimelineSelection(state.selectedShapeId);
  }

  Shape? topShapeAtPoint(
    Offset point, {
    required double viewportScale,
    Set<String>? excludeIds,
  }) {
    return _selectionService.topShapeAtPoint(
      state.shapes,
      point,
      _document.quadTree,
      viewportScale: viewportScale,
      excludeIds: excludeIds,
    );
  }

  /// Hit tests shapes at a point and returns the shape ID (for fill tool).
  String? hitTestShapeAt(Offset point, {required double viewportScale}) {
    final shape = topShapeAtPoint(point, viewportScale: viewportScale);
    return shape?.id;
  }

  SelectionContext _selectionContext() => SelectionContext(
    shapes: state.shapes,
    selectionMode: state.selectionMode,
    selectedShapeId: state.selectedShapeId,
    selectedShapeIds: state.selectedShapeIds,
  );

  ResolvedSelection _resolveSelectionForAvailableIds({
    required SelectionMode mode,
    required Set<String> availableIds,
    required String? selectedShapeId,
    required List<String> selectedShapeIds,
  }) {
    var resolvedId =
        selectedShapeId != null && availableIds.contains(selectedShapeId)
        ? selectedShapeId
        : null;
    var resolvedIds = selectedShapeIds
        .where(availableIds.contains)
        .toList(growable: false);

    if (mode == SelectionMode.single) {
      if (resolvedId == null && resolvedIds.isNotEmpty) {
        resolvedId = resolvedIds.first;
      }
      resolvedIds = resolvedId != null
          ? List<String>.unmodifiable([resolvedId])
          : const <String>[];
    } else if (resolvedId != null && !resolvedIds.contains(resolvedId)) {
      resolvedIds = List<String>.unmodifiable([resolvedId, ...resolvedIds]);
    } else {
      resolvedIds = List<String>.unmodifiable(resolvedIds);
    }

    return ResolvedSelection(
      selectedShapeId: resolvedId,
      selectedShapeIds: resolvedIds,
    );
  }

  Shape _translateShape(Shape shape, Offset delta) {
    return _transformService.translate(shape, delta);
  }

  Rect? _shapeBounds(Shape shape) {
    return _transformService.shapeBounds(shape);
  }

  CanvasDocument _updateDocumentFrame({
    required List<Shape> shapes,
    String? layerId,
    int? frameIndex,
  }) {
    return state.document.updateFrame(
      layerId: layerId ?? state.activeLayerId,
      frameIndex: frameIndex ?? state.currentFrame,
      shapes: shapes,
    );
  }

  CanvasLayer _resolveLayer(CanvasDocument document, String layerId) {
    return document.layerById(layerId) ?? document.layers.first;
  }

  _ShapeLocation? _findShapeLocation(String shapeId) {
    for (final layer in state.document.layers) {
      final frame = layer.frameAt(state.currentFrame);
      final index = frame.shapes.indexWhere((shape) => shape.id == shapeId);
      if (index != -1) {
        return _ShapeLocation(
          layerId: layer.id,
          shapes: frame.shapes,
          index: index,
        );
      }
    }
    return null;
  }

  String? _findLayerIdForShape(String shapeId) {
    return _findShapeLocation(shapeId)?.layerId;
  }

  String? _findLayerIdForGroup(String groupId) {
    for (final layer in state.document.layers) {
      final frame = layer.frameAt(state.currentFrame);
      if (frame.shapes.any((shape) => shape.groupId == groupId)) {
        return layer.id;
      }
    }
    return null;
  }

  void _applyLayerShapes(
    String layerId,
    List<Shape> shapes, {
    bool rebuildQuadTree = true,
  }) {
    final previousShapes = _resolveLayer(
      state.document,
      layerId,
    ).frameAt(state.currentFrame).shapes;
    final immutableShapes = List<Shape>.unmodifiable(shapes);
    var nextDocument = _updateDocumentFrame(
      shapes: immutableShapes,
      layerId: layerId,
    );
    nextDocument = _propagateAddedShapesToAllFrames(
      document: nextDocument,
      layerId: layerId,
      currentFrame: state.currentFrame,
      previousShapes: previousShapes,
      currentShapes: immutableShapes,
    );
    if (layerId == state.activeLayerId) {
      state = state.copyWith(
        document: nextDocument,
        shapes: immutableShapes,
        inProgressStroke: const [],
      );
      if (rebuildQuadTree) {
        _document.rebuildQuadTree(immutableShapes);
      }
    } else {
      state = state.copyWith(document: nextDocument);
    }
  }

  void _deleteShapeIdsEverywhere(
    Set<String> shapeIds, {
    required bool forceClearSelection,
  }) {
    if (shapeIds.isEmpty) return;
    final previousState = state;
    final nextDocument = _removeShapeIdsFromDocument(
      document: state.document,
      shapeIds: shapeIds,
    );
    if (identical(nextDocument, state.document)) return;

    final nextLayer = _resolveLayer(nextDocument, state.activeLayerId);
    final nextShapes = List<Shape>.unmodifiable(
      nextLayer.frameAt(state.currentFrame).shapes,
    );
    final availableIds = {for (final shape in nextShapes) shape.id};
    final resolvedSelection = forceClearSelection
        ? null
        : _resolveSelectionForAvailableIds(
            mode: previousState.selectionMode,
            availableIds: availableIds,
            selectedShapeId: previousState.selectedShapeId,
            selectedShapeIds: previousState.selectedShapeIds,
          );

    state = state.copyWith(
      document: nextDocument,
      shapes: nextShapes,
      selectedShapeId: forceClearSelection
          ? null
          : resolvedSelection?.selectedShapeId,
      selectedShapeIds: forceClearSelection
          ? const <String>[]
          : resolvedSelection?.selectedShapeIds,
      clearSelection: forceClearSelection,
      inProgressStroke: const [],
    );
    _recentObjectTimelineSelectionIds.removeWhere(shapeIds.contains);
    _document.rebuildQuadTree(nextShapes);
    _pushHistory();
  }

  CanvasDocument _removeShapeIdsFromDocument({
    required CanvasDocument document,
    required Set<String> shapeIds,
  }) {
    if (shapeIds.isEmpty) return document;

    var frameShapesChanged = false;
    final updatedLayers = <CanvasLayer>[];
    for (final layer in document.layers) {
      var layerChanged = false;
      final updatedFrames = Map<int, CanvasFrame>.from(layer.frames);
      for (final entry in layer.frames.entries) {
        final frame = entry.value;
        var frameChanged = false;
        final nextShapes = <Shape>[];
        for (final shape in frame.shapes) {
          if (shapeIds.contains(shape.id)) {
            frameChanged = true;
            continue;
          }
          final parentId = shape.parentId;
          if (parentId != null && shapeIds.contains(parentId)) {
            nextShapes.add(shape.copyWith(clearParentId: true));
            frameChanged = true;
            continue;
          }
          nextShapes.add(shape);
        }
        if (!frameChanged) continue;
        updatedFrames[entry.key] = frame.copyWith(
          shapes: List<Shape>.unmodifiable(nextShapes),
        );
        layerChanged = true;
      }
      if (layerChanged) {
        frameShapesChanged = true;
        updatedLayers.add(layer.copyWith(frames: updatedFrames));
      } else {
        updatedLayers.add(layer);
      }
    }

    final nextObjectTimeline = document.objectTimeline.removeShapes(shapeIds);
    final objectTimelineChanged = nextObjectTimeline != document.objectTimeline;
    if (!frameShapesChanged && !objectTimelineChanged) {
      return document;
    }

    return document.copyWith(
      layers: updatedLayers,
      objectTimeline: nextObjectTimeline,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _loadFrame({
    required String layerId,
    required int frameIndex,
  }) async {
    final previousState = state;
    final resolution = _resolveFrameLoadShapes(
      document: state.document,
      layerId: layerId,
      frameIndex: frameIndex,
    );
    final layer = resolution.layer;
    final immutableShapes = List<Shape>.unmodifiable(resolution.shapes);
    final availableIds = {for (final shape in immutableShapes) shape.id};
    final resolvedSelection = _resolveSelectionForAvailableIds(
      mode: previousState.selectionMode,
      availableIds: availableIds,
      selectedShapeId: previousState.selectedShapeId,
      selectedShapeIds: previousState.selectedShapeIds,
    );
    final didExtend = frameIndex >= resolution.document.frameCount;
    final nextDocument = didExtend
        ? resolution.document.copyWith(
            frameCount: frameIndex + 1,
            updatedAt: DateTime.now(),
          )
        : resolution.document;
    state = state.copyWith(
      document: nextDocument,
      activeLayerId: layer.id,
      currentFrame: frameIndex,
      shapes: immutableShapes,
      selectedShapeId: resolvedSelection.selectedShapeId,
      selectedShapeIds: resolvedSelection.selectedShapeIds,
      inProgressStroke: const [],
    );
    // Store base shapes BEFORE keyframe transforms are applied.
    // _baseShapes keeps clean layer geometry for document saves and history.
    _baseShapes = immutableShapes;
    _sceneCameraKeyframeViewModel.applySceneCameraForFrame(frameIndex);
    _objectKeyframeViewModel.applyObjectKeyframesForFrame(frameIndex);
    _document.rebuildQuadTree(state.shapes);
    if (didExtend || resolution.repairedMissingShapes) {
      _queueAutosave();
    }
  }

  Future<void> _applyDocument(
    CanvasDocument document, {
    String? activeLayerId,
    int? frameIndex,
  }) async {
    final normalizedDocument = _normalizeDocumentForLoad(document);
    final index = frameIndex ?? 0;
    final resolution = _resolveFrameLoadShapes(
      document: normalizedDocument,
      layerId: activeLayerId ?? normalizedDocument.layers.first.id,
      frameIndex: index,
    );
    final layer = resolution.layer;
    final immutableShapes = List<Shape>.unmodifiable(resolution.shapes);
    final initialSelectedShapeId = immutableShapes.isNotEmpty
        ? immutableShapes.first.id
        : null;
    final initialSelectedShapeIds = initialSelectedShapeId == null
        ? const <String>[]
        : <String>[initialSelectedShapeId];
    final nextActiveTool = state.activeTool == EditorTool.nodeEdit
        ? EditorTool.select
        : state.activeTool;

    // Show shapes immediately for fast initial display
    state = state.copyWith(
      document: resolution.document,
      activeLayerId: layer.id,
      currentFrame: index,
      shapes: immutableShapes,
      selectedShapeId: initialSelectedShapeId,
      selectedShapeIds: initialSelectedShapeIds,
      clearSelection: initialSelectedShapeId == null,
      activeTool: nextActiveTool,
      nodeEditState: NodeEditState.initial,
      pointModeState: PointModeState.initial,
      isLinkingMode: false,
      clearLinkingSource: true,
      isSpatialDrawMode: false,
      clearActiveSpatialObjectId: true,
      clearMergePreview: true,
      inProgressStroke: const [],
      clearSceneCamera: true,
    );
    // Store base shapes before keyframe transforms are applied.
    _baseShapes = immutableShapes;
    _sceneCameraKeyframeViewModel.applySceneCameraForFrame(index);
    _objectKeyframeViewModel.applyObjectKeyframesForFrame(index);
    _document.resetHistory(
      shapes: _baseShapes,
      selectedId: state.selectedShapeId,
      selectedIds: state.selectedShapeIds,
      frameIndex: index,
      activeLayerId: layer.id,
      sceneCameraTimeline: state.document.sceneCameraTimeline,
      objectTimeline: state.document.objectTimeline,
      sceneCamera: state.sceneCamera,
    );
    _document.rebuildQuadTree(state.shapes);
    _syncIdCounters(resolution.document);
    _recentObjectTimelineSelectionIds.clear();
    _rememberObjectTimelineSelection(state.selectedShapeId);

    _documentViewModel.cancelAutosave();
  }

  CanvasDocument _normalizeDocumentForLoad(CanvasDocument document) {
    if (document.layers.isNotEmpty) return document;
    final fallbackLayer = CanvasLayer(
      id: 'layer-1',
      name: 'Layer 1',
      frames: {0: CanvasFrame(index: 0)},
    );
    return document.copyWith(
      layers: [fallbackLayer],
      frameCount: math.max(1, document.frameCount),
      updatedAt: DateTime.now(),
    );
  }

  _FrameLoadShapeResolution _resolveFrameLoadShapes({
    required CanvasDocument document,
    required String layerId,
    required int frameIndex,
  }) {
    final result = _frameShapeResolver.resolveFrameLoadShapes(
      document: document,
      layerId: layerId,
      frameIndex: frameIndex,
    );
    return _FrameLoadShapeResolution(
      document: result.document,
      layer: result.layer,
      shapes: result.shapes,
      repairedMissingShapes: result.repairedMissingShapes,
    );
  }

  void _syncIdCounters(CanvasDocument document) {
    _shapeGroupingService.syncIdCounters(document);
    var maxShape = 0;
    var maxLayer = 0;
    var maxSpatial = 0;
    for (final layer in document.layers) {
      maxLayer = math.max(maxLayer, _parseCounter(layer.id, 'layer-'));
      for (final frame in layer.frames.values) {
        for (final shape in frame.shapes) {
          maxShape = math.max(maxShape, _parseCounter(shape.id, 'shape-'));
          final spatialId = shape.spatialObjectId;
          if (spatialId != null) {
            maxSpatial = math.max(
              maxSpatial,
              _parseCounter(spatialId, 'spatial-'),
            );
          }
        }
      }
    }
    // Reset counters to match the loaded document (not max with existing)
    // This ensures each project gets its own counter starting point
    _shapeCounter = maxShape;
    _layerCounter = math.max(maxLayer, document.layers.length);
    _spatialCounter = maxSpatial;
  }

  int _parseCounter(String id, String prefix) {
    if (!id.startsWith(prefix)) return 0;
    final value = int.tryParse(id.substring(prefix.length));
    return value ?? 0;
  }

  void _rememberObjectTimelineSelection(String? shapeId) {
    if (shapeId == null) return;
    _recentObjectTimelineSelectionIds.remove(shapeId);
    _recentObjectTimelineSelectionIds.insert(0, shapeId);
    if (_recentObjectTimelineSelectionIds.length >
        _maxRecentObjectTimelineTracks) {
      _recentObjectTimelineSelectionIds.removeRange(
        _maxRecentObjectTimelineTracks,
        _recentObjectTimelineSelectionIds.length,
      );
    }
  }

  void _setShapesAndRebuild(
    List<Shape> shapes, {
    String? selectedShapeId,
    List<String>? selectedShapeIds,
    bool clearSelection = false,
    bool rebuildQuadTree = true,
    bool propagateAddedShapes = true,
    Set<String> nonPersistentShapeIds = const <String>{},
  }) {
    // Resolve base (pre-keyframe) shapes to save to the document.
    // Shapes that the user didn't modify are reverted to their base versions
    // so that keyframe transforms are not baked into layer frame data.
    final baseForSave = _resolveBaseShapesForSave(shapes);
    final immutableBase = List<Shape>.unmodifiable(
      _applyNonPersistentBaseShapes(baseForSave, nonPersistentShapeIds),
    );

    final previousShapes = _resolveLayer(
      state.document,
      state.activeLayerId,
    ).frameAt(state.currentFrame).shapes;
    var nextDocument = _updateDocumentFrame(shapes: immutableBase);
    if (propagateAddedShapes) {
      nextDocument = _propagateAddedShapesToAllFrames(
        document: nextDocument,
        layerId: state.activeLayerId,
        currentFrame: state.currentFrame,
        previousShapes: previousShapes,
        currentShapes: immutableBase,
      );
    }

    // Update base shapes cache.
    _baseShapes = immutableBase;

    // Display shapes keep the incoming list (user modifications visible,
    // existing keyframe display preserved). Keyframes are NOT re-applied
    // here — that only happens in _loadFrame when navigating frames.
    final immutableDisplay = List<Shape>.unmodifiable(shapes);
    state = state.copyWith(
      document: nextDocument,
      shapes: immutableDisplay,
      selectedShapeId: selectedShapeId,
      selectedShapeIds: selectedShapeIds,
      clearSelection: clearSelection,
      inProgressStroke: const [],
    );
    _rememberObjectTimelineSelection(state.selectedShapeId);
    if (rebuildQuadTree) {
      _document.rebuildQuadTree(immutableDisplay);
    }
  }

  /// Maps incoming shapes back to their base (pre-keyframe) versions for
  /// document storage.
  List<Shape> _resolveBaseShapesForSave(List<Shape> incomingShapes) {
    return _frameShapeResolver.resolveBaseShapesForSave(
      incomingShapes: incomingShapes,
      displayShapes: state.shapes,
      baseShapes: _baseShapes,
    );
  }

  bool _applyGlobalStylePatch({
    required Set<String> shapeIds,
    required ShapeStylePatch patch,
    bool addToHistory = true,
  }) {
    if (shapeIds.isEmpty || patch.isNoop) return false;

    final result = _styleEditService.applyPatchToDocument(
      document: state.document,
      shapeIds: shapeIds,
      patch: patch,
    );
    final nextDisplay = _applyStylePatchToShapes(
      shapes: state.shapes,
      shapeIds: shapeIds,
      patch: patch,
    );
    final nextBase = _applyStylePatchToShapes(
      shapes: _baseShapes,
      shapeIds: shapeIds,
      patch: patch,
    );

    if (!result.changed &&
        identical(nextDisplay, state.shapes) &&
        identical(nextBase, _baseShapes)) {
      return false;
    }

    state = state.copyWith(
      document: result.document,
      shapes: List<Shape>.unmodifiable(nextDisplay),
      inProgressStroke: const [],
    );
    _baseShapes = List<Shape>.unmodifiable(nextBase);
    _document.rebuildQuadTree(state.shapes);
    if (addToHistory) {
      _pushHistoryDeferred();
    }
    return true;
  }

  List<Shape> _applyStylePatchToShapes({
    required List<Shape> shapes,
    required Set<String> shapeIds,
    required ShapeStylePatch patch,
  }) {
    if (shapes.isEmpty || shapeIds.isEmpty || patch.isNoop) {
      return shapes;
    }
    var changed = false;
    final next = shapes
        .map((shape) {
          if (!shapeIds.contains(shape.id)) return shape;
          if (!patch.affectsShape(shape)) return shape;
          changed = true;
          return patch.applyToShape(shape);
        })
        .toList(growable: false);
    return changed ? next : shapes;
  }

  TransformEditPersistencePlan _buildTransformEditPersistencePlan(
    Iterable<String> shapeIds, {
    required Set<ObjectKeyChannel> channels,
  }) {
    return _transformEditPersistenceService.buildPlan(
      timeline: state.document.objectTimeline,
      frame: state.currentFrame,
      autoKeyEnabled: state.autoKeyEnabled,
      shapeIds: shapeIds,
      channels: channels,
    );
  }

  void _applyGlobalUnkeyedTransformEdits(TransformEditPersistencePlan plan) {
    if (!plan.hasGlobalChannels) return;
    final sourceById = <String, Shape>{};
    for (final shape in state.shapes) {
      if (plan.globalChannelsByShapeId.containsKey(shape.id)) {
        sourceById[shape.id] = shape;
      }
    }
    if (sourceById.isEmpty) return;

    var nextDocument = state.document;
    for (final entry in plan.globalChannelsByShapeId.entries) {
      final source = sourceById[entry.key];
      if (source == null) continue;
      nextDocument = _updateShapeInAllFrames(
        document: nextDocument,
        layerId: state.activeLayerId,
        shapeId: entry.key,
        transform: (target) => _applyTransformChannelsFromSourceShape(
          target: target,
          source: source,
          channels: entry.value,
        ),
      );
    }

    if (identical(nextDocument, state.document)) return;
    final nextLayer = _resolveLayer(nextDocument, state.activeLayerId);
    _baseShapes = List<Shape>.unmodifiable(
      nextLayer.frameAt(state.currentFrame).shapes,
    );
    state = state.copyWith(document: nextDocument);
  }

  Shape _applyTransformChannelsFromSourceShape({
    required Shape target,
    required Shape source,
    required Set<ObjectKeyChannel> channels,
  }) {
    if (channels.isEmpty) return target;
    var next = target;
    if (channels.contains(ObjectKeyChannel.position)) {
      next = next.copyWith(
        points: source.points.toList(growable: false),
        contours: source.contours
            .map((contour) => contour.toList(growable: false))
            .toList(growable: false),
        bezierPoints: source.bezierPoints?.toList(growable: false),
        clearBezierPoints: source.bezierPoints == null,
        bounds: source.bounds,
        pointPressures: source.pointPressures?.toList(growable: false),
        clearPointPressures: source.pointPressures == null,
        eraseContours: source.eraseContours
            ?.map((contour) => contour.toList(growable: false))
            .toList(growable: false),
        clearEraseContours: source.eraseContours == null,
        translation: source.translation,
        pivot: source.transform.pivot,
      );
    }
    if (channels.contains(ObjectKeyChannel.rotation)) {
      next = next.copyWith(rotation: source.rotation);
    }
    if (channels.contains(ObjectKeyChannel.scale)) {
      next = next.copyWith(scaleX: source.scaleX, scaleY: source.scaleY);
    }
    return next;
  }

  /// For animatable edits, avoid writing frame-local values when they should be
  /// controlled by object keyframes.
  ///
  /// Rules:
  /// - If auto-key is ON, edited shapes are keyframed and frame snapshots are
  ///   not used for those channels.
  /// - If a shape already has a key on the current frame, that key is updated
  ///   and frame snapshots are not used.
  /// - With auto-key OFF and no key on the current frame:
  ///   frame 0 edits persist as base/rest values, non-zero frame edits do not.
  Set<String> _nonPersistentTransformShapeIds(Iterable<String> shapeIds) {
    final uniqueIds = shapeIds.toSet();
    if (uniqueIds.isEmpty) return const <String>{};
    final forceNonPersistent = <String>{};
    final timeline = state.document.objectTimeline;
    final frame = state.currentFrame;
    final autoKey = state.autoKeyEnabled;
    for (final id in uniqueIds) {
      final hasKeyAtFrame = timeline.containsFrame(id, frame);
      if (autoKey || hasKeyAtFrame || frame > 0) {
        forceNonPersistent.add(id);
      }
    }
    return forceNonPersistent;
  }

  void _syncObjectKeyframesForEditedShapeIds(
    Iterable<String> shapeIds, {
    Set<ObjectKeyChannel> channels = kAllObjectKeyChannels,
    TransformEditPersistencePlan? transformPersistencePlan,
  }) {
    final frame = state.currentFrame;
    if (frame < 0) return;
    final ids = shapeIds.toSet();
    if (ids.isEmpty) return;
    final normalizedChannels = channels.isEmpty
        ? kAllObjectKeyChannels
        : Set<ObjectKeyChannel>.unmodifiable(channels);

    final autoKey = state.autoKeyEnabled;
    var nextTimeline = state.document.objectTimeline;
    var changed = false;
    for (final id in ids) {
      Shape? shape;
      for (final candidate in state.shapes) {
        if (candidate.id == id) {
          shape = candidate;
          break;
        }
      }
      if (shape == null) continue;
      final existing = nextTimeline.trackForShape(id)?.atFrame(frame);
      Set<ObjectKeyChannel> channelsToWrite = normalizedChannels;
      if (autoKey) {
        channelsToWrite = normalizedChannels;
      } else if (existing == null) {
        continue;
      } else {
        channelsToWrite = normalizedChannels
            .where(existing.keysChannel)
            .toSet();
        if (channelsToWrite.isEmpty) continue;
      }

      final keyframe = existing == null
          ? ObjectTransformKeyframe.fromShape(
              frame: frame,
              shape: shape,
              keyedChannels: channelsToWrite,
            )
          : existing.withShapeChannels(
              shape: shape,
              channels: channelsToWrite,
              mergeKeyedChannels: true,
            );
      final updated = nextTimeline.upsert(shapeId: id, keyframe: keyframe);
      if (updated != nextTimeline) {
        nextTimeline = updated;
        changed = true;
      }
    }

    if (changed) {
      final nextFrameCount = frame >= state.document.frameCount
          ? frame + 1
          : state.document.frameCount;
      final nextDocument = state.document.copyWith(
        objectTimeline: nextTimeline,
        frameCount: nextFrameCount,
        updatedAt: DateTime.now(),
      );
      state = state.copyWith(document: nextDocument);
    }

    if (transformPersistencePlan != null) {
      _applyGlobalUnkeyedTransformEdits(transformPersistencePlan);
    }
  }

  List<Shape> _applyNonPersistentBaseShapes(
    List<Shape> candidateShapes,
    Set<String> nonPersistentShapeIds,
  ) {
    if (candidateShapes.isEmpty || nonPersistentShapeIds.isEmpty) {
      return candidateShapes;
    }
    if (_baseShapes.isEmpty) return candidateShapes;
    final baseById = {for (final shape in _baseShapes) shape.id: shape};
    var changed = false;
    final resolved = candidateShapes
        .map((shape) {
          if (!nonPersistentShapeIds.contains(shape.id)) return shape;
          final baseShape = baseById[shape.id];
          if (baseShape == null) return shape;
          if (identical(baseShape, shape)) return shape;
          changed = true;
          return baseShape;
        })
        .toList(growable: false);
    return changed ? resolved : candidateShapes;
  }

  CanvasDocument _propagateAddedShapesToAllFrames({
    required CanvasDocument document,
    required String layerId,
    required int currentFrame,
    required List<Shape> previousShapes,
    required List<Shape> currentShapes,
  }) {
    if (currentShapes.isEmpty) return document;

    final previousIds = {for (final shape in previousShapes) shape.id};
    final addedShapes = currentShapes
        .where((shape) => !previousIds.contains(shape.id))
        .map((shape) => shape.copyWith())
        .toList(growable: false);
    if (addedShapes.isEmpty) return document;

    final layer = document.layerById(layerId);
    if (layer == null || layer.frames.isEmpty) return document;

    final updatedFrames = Map<int, CanvasFrame>.from(layer.frames);
    var changed = false;
    for (final entry in layer.frames.entries) {
      final frameIndex = entry.key;
      if (frameIndex == currentFrame) continue;

      final frame = entry.value;
      final existingIds = {for (final shape in frame.shapes) shape.id};
      if (addedShapes.every((shape) => existingIds.contains(shape.id))) {
        continue;
      }

      final merged = List<Shape>.from(frame.shapes);
      for (var i = addedShapes.length - 1; i >= 0; i--) {
        final addedShape = addedShapes[i];
        if (existingIds.contains(addedShape.id)) continue;
        merged.insert(0, addedShape.copyWith());
        existingIds.add(addedShape.id);
      }
      updatedFrames[frameIndex] = frame.copyWith(
        shapes: List<Shape>.unmodifiable(merged),
      );
      changed = true;
    }

    if (!changed) return document;
    final nextLayer = layer.copyWith(frames: updatedFrames);
    return document.upsertLayer(nextLayer).copyWith(updatedAt: DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // Structural propagation helpers
  // ---------------------------------------------------------------------------

  /// Reorders a shape by [shapeId] within [layerId] across ALL explicit frames.
  ///
  /// Determines the target position from the canonical [orderedShapeIds] and
  /// applies the same relative ordering to every frame.
  CanvasDocument _reorderShapeInAllFrames({
    required CanvasDocument document,
    required String layerId,
    required List<String> orderedShapeIds,
  }) {
    final layer = document.layerById(layerId);
    if (layer == null || layer.frames.isEmpty) return document;

    final updatedFrames = Map<int, CanvasFrame>.from(layer.frames);
    var changed = false;
    for (final entry in layer.frames.entries) {
      final frame = entry.value;
      final currentIds = frame.shapes.map((s) => s.id).toList();
      // Build the desired order for this frame: keep only IDs present in this
      // frame, in the canonical order.
      final presentIds = currentIds.toSet();
      final desiredOrder = orderedShapeIds
          .where((id) => presentIds.contains(id))
          .toList();
      // Check if order already matches.
      final currentOrder = currentIds
          .where((id) => desiredOrder.contains(id))
          .toList();
      if (_listEquals(currentOrder, desiredOrder)) continue;
      // Rebuild the shapes list in the desired order.
      final shapeById = {for (final s in frame.shapes) s.id: s};
      final reordered = desiredOrder
          .map((id) => shapeById[id]!)
          .toList(growable: false);
      updatedFrames[entry.key] = frame.copyWith(
        shapes: List<Shape>.unmodifiable(reordered),
      );
      changed = true;
    }
    if (!changed) return document;
    final nextLayer = layer.copyWith(frames: updatedFrames);
    return document.upsertLayer(nextLayer).copyWith(updatedAt: DateTime.now());
  }

  /// Moves shapes identified by [shapeIds] from [sourceLayerId] to
  /// [targetLayerId] across ALL explicit frames.
  ///
  /// Optionally transforms each moved shape via [transformShape].
  CanvasDocument _moveShapesBetweenLayersInAllFrames({
    required CanvasDocument document,
    required String sourceLayerId,
    required String targetLayerId,
    required Set<String> shapeIds,
    Shape Function(Shape)? transformShape,
  }) {
    if (shapeIds.isEmpty || sourceLayerId == targetLayerId) return document;
    final sourceLayer = document.layerById(sourceLayerId);
    final targetLayer = document.layerById(targetLayerId);
    if (sourceLayer == null || targetLayer == null) return document;
    final transform = transformShape ?? (s) => s;

    // Collect all explicit frame indices across both layers.
    final allFrameIndices = <int>{
      ...sourceLayer.frames.keys,
      ...targetLayer.frames.keys,
    };

    var updatedSourceFrames = Map<int, CanvasFrame>.from(sourceLayer.frames);
    var updatedTargetFrames = Map<int, CanvasFrame>.from(targetLayer.frames);
    var sourceChanged = false;
    var targetChanged = false;

    for (final frameIndex in allFrameIndices) {
      // Source: remove shapes.
      final sourceFrame = sourceLayer.frames[frameIndex];
      if (sourceFrame != null) {
        final before = sourceFrame.shapes;
        final after = before
            .where((s) => !shapeIds.contains(s.id))
            .toList(growable: false);
        if (after.length != before.length) {
          // Collect the shapes being moved (in source order).
          final moving = before.where((s) => shapeIds.contains(s.id)).toList();
          updatedSourceFrames[frameIndex] = sourceFrame.copyWith(
            shapes: List<Shape>.unmodifiable(after),
          );
          sourceChanged = true;

          // Target: add moved shapes (avoid duplicates).
          final targetFrame =
              updatedTargetFrames[frameIndex] ?? CanvasFrame(index: frameIndex);
          final existingIds = {for (final s in targetFrame.shapes) s.id};
          final toAdd = moving
              .where((s) => !existingIds.contains(s.id))
              .map(transform)
              .toList(growable: false);
          if (toAdd.isNotEmpty) {
            updatedTargetFrames[frameIndex] = targetFrame.copyWith(
              shapes: List<Shape>.unmodifiable([
                ...targetFrame.shapes,
                ...toAdd,
              ]),
            );
            targetChanged = true;
          }
        }
      }
    }

    var result = document;
    if (sourceChanged) {
      result = result.upsertLayer(
        sourceLayer.copyWith(frames: updatedSourceFrames),
      );
    }
    if (targetChanged) {
      result = result.upsertLayer(
        targetLayer.copyWith(frames: updatedTargetFrames),
      );
    }
    if (sourceChanged || targetChanged) {
      result = result.copyWith(updatedAt: DateTime.now());
    }
    return result;
  }

  /// Updates a shape property (e.g. groupId) across ALL explicit frames in a
  /// layer.
  CanvasDocument _updateShapeInAllFrames({
    required CanvasDocument document,
    required String layerId,
    required String shapeId,
    required Shape Function(Shape) transform,
  }) {
    final layer = document.layerById(layerId);
    if (layer == null || layer.frames.isEmpty) return document;

    final updatedFrames = Map<int, CanvasFrame>.from(layer.frames);
    var changed = false;
    for (final entry in layer.frames.entries) {
      final frame = entry.value;
      var frameChanged = false;
      final nextShapes = frame.shapes
          .map((s) {
            if (s.id != shapeId) return s;
            frameChanged = true;
            return transform(s);
          })
          .toList(growable: false);
      if (!frameChanged) continue;
      updatedFrames[entry.key] = frame.copyWith(
        shapes: List<Shape>.unmodifiable(nextShapes),
      );
      changed = true;
    }
    if (!changed) return document;
    final nextLayer = layer.copyWith(frames: updatedFrames);
    return document.upsertLayer(nextLayer).copyWith(updatedAt: DateTime.now());
  }

  Future<void> _applySnapshot(HistorySnapshot snap) async {
    // Cancel any in-progress drawing
    if (_drawingViewModel.isDrawing) {
      _drawingViewModel.cancelDrawing(state);
    }
    final applyGeneration = _historyViewModel.applyGeneration;
    _historyViewModel.setApplyingHistory(true);
    _selectionDirty = false;
    var applied = false;
    try {
      if (_isHistoryApplyStale(applyGeneration)) return;
      final immutableShapes = List<Shape>.unmodifiable(snap.shapes);
      final availableIds = {for (final shape in immutableShapes) shape.id};
      final resolvedSelection = snap.resolveSelection(
        mode: state.selectionMode,
        availableIds: availableIds,
      );
      final nextDocument =
          _updateDocumentFrame(
            shapes: immutableShapes,
            layerId: snap.activeLayerId,
            frameIndex: snap.frameIndex,
          ).copyWith(
            sceneCameraTimeline: snap.sceneCameraTimeline,
            objectTimeline: snap.objectTimeline,
          );
      state = state.copyWith(
        document: nextDocument,
        activeLayerId: snap.activeLayerId,
        currentFrame: snap.frameIndex,
        shapes: immutableShapes,
        selectedShapeId: resolvedSelection.selectedShapeId,
        selectedShapeIds: resolvedSelection.selectedShapeIds,
        inProgressStroke: const [],
        sceneCamera: snap.sceneCamera,
      );
      // Restore base shapes before keyframe transforms are re-applied.
      _baseShapes = immutableShapes;
      _sceneCameraKeyframeViewModel.applySceneCameraForFrame(snap.frameIndex);
      _objectKeyframeViewModel.applyObjectKeyframesForFrame(snap.frameIndex);
      _document.rebuildQuadTree(state.shapes);
      _rememberObjectTimelineSelection(state.selectedShapeId);
      applied = true;
    } finally {
      _historyViewModel.setApplyingHistory(false);
      if (applied) {
        _queueAutosave();
      }
    }
  }

  void _pushHistory() {
    if (_historyViewModel.applyingHistory) return;
    _selectionDirty = false;
    _document.pushHistory(
      shapes: _baseShapes,
      selectedId: state.selectedShapeId,
      selectedIds: state.selectedShapeIds,
      frameIndex: state.currentFrame,
      activeLayerId: state.activeLayerId,
      sceneCameraTimeline: state.document.sceneCameraTimeline,
      objectTimeline: state.document.objectTimeline,
      sceneCamera: state.sceneCamera,
    );
    _queueAutosave();
  }

  void _pushHistoryDeferred() {
    if (_historyViewModel.applyingHistory || _pendingHistoryPush) return;
    _pendingHistoryPush = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pendingHistoryPush = false;
      if (_historyViewModel.applyingHistory) return;
      _selectionDirty = false;
      _document.pushHistory(
        shapes: _baseShapes,
        selectedId: state.selectedShapeId,
        selectedIds: state.selectedShapeIds,
        frameIndex: state.currentFrame,
        activeLayerId: state.activeLayerId,
        sceneCameraTimeline: state.document.sceneCameraTimeline,
        objectTimeline: state.document.objectTimeline,
        sceneCamera: state.sceneCamera,
      );
      _queueAutosave();
    });
  }

  QuadTree get quadTree => _document.quadTree;
  void rebuildQuadTree() => _document.rebuildQuadTree(state.shapes);

  // ─────────────────────────────────────────────────────────────────────────
  // Parent-Child Hierarchy / Linking Mode (delegated to LinkingModeViewModel)
  // ─────────────────────────────────────────────────────────────────────────

  void enterLinkingMode() => _linkingModeViewModel.enterLinkingMode();
  void exitLinkingMode() => _linkingModeViewModel.exitLinkingMode();
  void completeLinking(String targetParentId) =>
      _linkingModeViewModel.completeLinking(targetParentId);
  void unlinkFromParent() => _linkingModeViewModel.unlinkFromParent();
  void unlinkAllChildren() => _linkingModeViewModel.unlinkAllChildren();
  Shape? getParentOf(Shape shape) => _linkingModeViewModel.getParentOf(shape);
  List<Shape> getChildrenOf(Shape shape) =>
      _linkingModeViewModel.getChildrenOf(shape);
  bool hasChildren(Shape shape) => _linkingModeViewModel.hasChildren(shape);

  void finalizeSelectionEdit() {
    if (!_selectionDirty) return;
    _pushHistory();

    // Refresh weighted edit state after shape modifications
    if (state.nodeEditState.useWeightedEdit) {
      refreshWeightedEditState();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Point Mode Drawing (delegated to PointModeViewModel)
  // ─────────────────────────────────────────────────────────────────────────

  void enterPointMode() => _pointModeViewModel.enterPointMode();
  void exitPointMode() => _pointModeViewModel.exitPointMode();
  void addPointModePoint(Offset point) =>
      _pointModeViewModel.addPointModePoint(point);
  void removeLastPointModePoint() =>
      _pointModeViewModel.removeLastPointModePoint();
  void setPointModeConnectionType(PointConnectionType type) =>
      _pointModeViewModel.setPointModeConnectionType(type);
  void togglePointModeClosed() => _pointModeViewModel.togglePointModeClosed();
  void finalizePointMode() => _pointModeViewModel.finalizePointMode();
}

final editorViewModelProvider = NotifierProvider<EditorViewModel, EditorState>(
  EditorViewModel.new,
);

class _FrameLoadShapeResolution {
  const _FrameLoadShapeResolution({
    required this.document,
    required this.layer,
    required this.shapes,
    required this.repairedMissingShapes,
  });

  final CanvasDocument document;
  final CanvasLayer layer;
  final List<Shape> shapes;
  final bool repairedMissingShapes;
}

class _ShapeLocation {
  const _ShapeLocation({
    required this.layerId,
    required this.shapes,
    required this.index,
  });

  final String layerId;
  final List<Shape> shapes;
  final int index;
}

/// Result type for merge validation.
enum MergeResultType {
  /// Merge completed successfully.
  success,

  /// Merge completed but some shapes were skipped.
  partialSuccess,

  /// Not enough shapes selected (need at least 2).
  notEnoughShapes,

  /// Selected shapes are on different layers - cannot merge across layers.
  crossLayerMerge,

  /// The layer containing the shapes was not found.
  layerNotFound,

  /// Some shapes were skipped during merge (invalid shapes).
  shapesSkipped,

  /// Merge produced no result (empty contours).
  emptyResult,
}

/// Result of validating and executing a merge operation.
class MergeValidationResult {
  const MergeValidationResult({
    required this.type,
    this.skipSummary,
    this.skippedCount = 0,
    this.mergedCount = 0,
  });

  final MergeResultType type;
  final String? skipSummary;
  final int skippedCount;
  final int mergedCount;

  /// Returns true if the merge was successful (fully or partially).
  bool get isSuccess =>
      type == MergeResultType.success || type == MergeResultType.partialSuccess;

  /// User-friendly message describing the result.
  String get message {
    switch (type) {
      case MergeResultType.success:
        return 'Merged $mergedCount shapes successfully';
      case MergeResultType.partialSuccess:
        final base = 'Merged $mergedCount shapes';
        if (skipSummary != null && skipSummary!.isNotEmpty) {
          return '$base (skipped $skippedCount: $skipSummary)';
        }
        return '$base (skipped $skippedCount shapes)';
      case MergeResultType.notEnoughShapes:
        return 'Select at least 2 shapes to merge';
      case MergeResultType.crossLayerMerge:
        return 'Cannot merge shapes from different layers';
      case MergeResultType.layerNotFound:
        return 'Layer not found';
      case MergeResultType.shapesSkipped:
        if (skipSummary != null && skipSummary!.isNotEmpty) {
          return 'All shapes skipped: $skipSummary';
        }
        return 'All shapes were skipped (invalid geometry)';
      case MergeResultType.emptyResult:
        return 'Merge produced no result';
    }
  }

  // Convenience constructors
  static const notEnoughShapes = MergeValidationResult(
    type: MergeResultType.notEnoughShapes,
  );
  static const crossLayerMerge = MergeValidationResult(
    type: MergeResultType.crossLayerMerge,
  );
  static const layerNotFound = MergeValidationResult(
    type: MergeResultType.layerNotFound,
  );
  static const emptyResult = MergeValidationResult(
    type: MergeResultType.emptyResult,
  );
}
