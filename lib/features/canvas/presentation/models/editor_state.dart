import 'dart:ui';

import 'package:animation_maker/core/constants/animation_constants.dart';
import 'package:animation_maker/features/canvas/domain/entities/camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/entities/spatial_object.dart';
import 'package:animation_maker/features/canvas/presentation/models/brush_settings.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/models/joystick_mode.dart';
import 'package:animation_maker/features/canvas/presentation/models/node_edit_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/point_mode_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/style_edit_scope.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brushes/brush_type.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

enum LeftPanelTab { layers, selection }

class EditorState {
  const EditorState({
    required this.document,
    required this.activeLayerId,
    required this.shapes,
    required this.activeTool,
    required this.selectedShapeId,
    required this.selectedShapeIds,
    required this.currentFrame,
    required this.isLeftPanelOpen,
    required this.leftPanelTab,
    required this.shapeDrawKind,
    required this.currentColor,
    required this.isPanMode,
    required this.currentBrush,
    required this.brushSettings,
    required this.eraserSettings,
    required this.isToolPanelOpen,
    required this.inProgressStroke,
    required this.palmRejectionEnabled,
    required this.groupingEnabled,
    required this.currentGroupId,
    required this.transformGroupAsOne,
    required this.selectionMode,
    required this.pivotSnapEnabled,
    required this.pivotSnapStrength,
    required this.pivotFlipWithObject,
    required this.strokeScaleWithShape,
    required this.isInteractingWithCanvas,
    required this.joystickControllerEnabled,
    required this.joystickMode,
    required this.camera,
    required this.isProcessingHeavyOperation,
    required this.groupNames,
    required this.nodeEditState,
    required this.isLinkingMode,
    bool isSpatialDrawMode = false,
    required this.spatialObjects,
    required this.activeSpatialObjectId,
    this.linkingSourceShapeId,
    this.shapeFillColor,
    this.mergePreviewShape,
    this.pointModeState = PointModeState.initial,
    this.sceneCamera,
    this.sceneCameraVisible = true,
    this.isTimelinePlaying = false,
    this.autoKeyEnabled = false,
    this.styleEditScope = StyleEditScope.global,
  }) : _isSpatialDrawMode = isSpatialDrawMode;

  factory EditorState.initial() {
    final document = CanvasDocument.singleLayer(
      id: 'document-1',
      title: 'Untitled',
      size: kDefaultCanvasSize,
      fps: kDefaultFps,
      frameCount: kDefaultFrameCount,
    );
    final activeLayerId = document.layers.first.id;
    final frame = document.layers.first.frameAt(0);

    final Map<BrushType, BrushSettings> defaultBrushSettings = {
      BrushType.standard: const BrushSettings(thickness: 4.0),
      BrushType.marker: const BrushSettings(thickness: 8.0),
      BrushType.pencil: const BrushSettings(thickness: 2.0, smoothness: 0.8),
      BrushType.hair: const BrushSettings(thickness: 3.0),
      BrushType.cube: const BrushSettings(thickness: 10.0),
      BrushType.gradient: const BrushSettings(thickness: 6.0),
      BrushType.mosaic: const BrushSettings(thickness: 12.0),
    };

    return EditorState(
      document: document,
      activeLayerId: activeLayerId,
      shapes: frame.shapes,
      activeTool: EditorTool.brush,
      selectedShapeId: null,
      selectedShapeIds: const <String>[],
      currentFrame: 0,
      isLeftPanelOpen: false,
      leftPanelTab: LeftPanelTab.layers,
      shapeDrawKind: ShapeKind.rectangle,
      currentColor: const Color(0xFF000000),
      isPanMode: false,
      currentBrush: BrushType.standard,
      brushSettings: defaultBrushSettings,
      eraserSettings: const BrushSettings(thickness: 15.0),
      isToolPanelOpen: false,
      inProgressStroke: const <PointVector>[],
      palmRejectionEnabled: false,
      groupingEnabled: false,
      currentGroupId: null,
      transformGroupAsOne: false,
      selectionMode: SelectionMode.single,
      pivotSnapEnabled: true,
      pivotSnapStrength: 0.5,
      pivotFlipWithObject: true,
      strokeScaleWithShape: false,
      shapeFillColor: null,
      isInteractingWithCanvas: false,
      joystickControllerEnabled: true,
      joystickMode: JoystickMode.move,
      camera: Camera.fitRect(
        worldRect: Rect.fromLTWH(
          0,
          0,
          kDefaultCanvasSize.width,
          kDefaultCanvasSize.height,
        ),
        viewportSize: kDefaultCanvasSize, // Will be updated when widget builds
      ),
      isProcessingHeavyOperation: false,
      groupNames: const {},
      nodeEditState: NodeEditState.initial,
      isLinkingMode: false,
      isSpatialDrawMode: false,
      spatialObjects: const [],
      activeSpatialObjectId: null,
      linkingSourceShapeId: null,
      autoKeyEnabled: false,
      styleEditScope: StyleEditScope.global,
    );
  }

  final CanvasDocument document;
  final String activeLayerId;
  final List<Shape> shapes;
  final EditorTool activeTool;
  final String? selectedShapeId;
  final List<String> selectedShapeIds;
  final int currentFrame;
  final bool isLeftPanelOpen;
  final LeftPanelTab leftPanelTab;
  final ShapeKind shapeDrawKind;
  final Color currentColor;
  final bool isPanMode;
  final BrushType currentBrush;
  final Map<BrushType, BrushSettings> brushSettings;
  final BrushSettings eraserSettings;
  final bool isToolPanelOpen;
  final List<PointVector> inProgressStroke;
  final bool palmRejectionEnabled;
  final bool groupingEnabled;
  final String? currentGroupId;
  final bool transformGroupAsOne;
  final SelectionMode selectionMode;
  final Color? shapeFillColor;
  final bool pivotSnapEnabled;
  final double pivotSnapStrength;
  final bool pivotFlipWithObject;
  final bool strokeScaleWithShape;
  final bool isInteractingWithCanvas;
  final bool joystickControllerEnabled;
  final JoystickMode joystickMode;
  final Camera camera;
  final bool isProcessingHeavyOperation;

  /// Viewport scale derived from camera zoom.
  /// This maintains backward compatibility with existing code.
  double get viewportScale => camera.zoom;
  final Map<String, String> groupNames;
  final NodeEditState nodeEditState;
  final Shape? mergePreviewShape;
  final bool isLinkingMode;
  final List<SpatialObject> spatialObjects;
  final String? activeSpatialObjectId;
  final bool? _isSpatialDrawMode;
  final String? linkingSourceShapeId;
  final PointModeState pointModeState;
  final SceneCamera? sceneCamera;
  final bool sceneCameraVisible;
  final bool isTimelinePlaying;
  final bool autoKeyEnabled;
  final StyleEditScope styleEditScope;

  /// Whether a scene camera exists.
  bool get hasSceneCamera => sceneCamera != null;

  /// Whether the camera tool is active.
  bool get isCameraMode => activeTool == EditorTool.camera;

  /// Whether we're currently in node editing mode.
  bool get isNodeEditMode => activeTool == EditorTool.nodeEdit;

  /// Whether spatial drawing mode is enabled.
  bool get isSpatialDrawMode => _isSpatialDrawMode ?? false;

  /// Whether a merge preview is currently being shown.
  bool get isMergePreviewActive => mergePreviewShape != null;

  /// Gets the currently selected shape, or null if none selected.
  Shape? get selectedShape {
    if (selectedShapeId == null) return null;
    try {
      return shapes.firstWhere((s) => s.id == selectedShapeId);
    } catch (_) {
      return null;
    }
  }

  /// Gets all shapes from all visible layers for the current frame.
  /// Layers are rendered with first layer on top (like Photoshop/Figma).
  /// Shapes within a layer: first shape on top, last shape at bottom.
  /// Use this for rendering; use [shapes] for editing the active layer.
  List<Shape> get allVisibleShapes {
    final result = <Shape>[];
    // Iterate in reverse so first layer (top of tree) renders on top
    for (var i = document.layers.length - 1; i >= 0; i--) {
      final layer = document.layers[i];
      if (!layer.isVisible) continue;
      final frame = layer.frameAt(currentFrame);
      // Reverse shapes so first shape (top of list) renders on top
      for (var j = frame.shapes.length - 1; j >= 0; j--) {
        result.add(frame.shapes[j]);
      }
    }
    return result;
  }

  EditorState copyWith({
    CanvasDocument? document,
    String? activeLayerId,
    List<Shape>? shapes,
    EditorTool? activeTool,
    String? selectedShapeId,
    List<String>? selectedShapeIds,
    int? currentFrame,
    bool? isLeftPanelOpen,
    LeftPanelTab? leftPanelTab,
    bool clearSelection = false,
    ShapeKind? shapeDrawKind,
    Color? currentColor,
    bool? isPanMode,
    BrushType? currentBrush,
    Map<BrushType, BrushSettings>? brushSettings,
    BrushSettings? eraserSettings,
    bool? isToolPanelOpen,
    List<PointVector>? inProgressStroke,
    bool? palmRejectionEnabled,
    bool? groupingEnabled,
    String? currentGroupId,
    bool? transformGroupAsOne,
    SelectionMode? selectionMode,
    Color? shapeFillColor,
    bool? pivotSnapEnabled,
    double? pivotSnapStrength,
    bool? pivotFlipWithObject,
    bool? strokeScaleWithShape,
    bool? isInteractingWithCanvas,
    bool? joystickControllerEnabled,
    JoystickMode? joystickMode,
    Camera? camera,
    bool? isProcessingHeavyOperation,
    Map<String, String>? groupNames,
    NodeEditState? nodeEditState,
    Shape? mergePreviewShape,
    bool clearMergePreview = false,
    bool? isLinkingMode,
    bool? isSpatialDrawMode,
    List<SpatialObject>? spatialObjects,
    String? activeSpatialObjectId,
    bool clearActiveSpatialObjectId = false,
    String? linkingSourceShapeId,
    bool clearLinkingSource = false,
    PointModeState? pointModeState,
    SceneCamera? sceneCamera,
    bool clearSceneCamera = false,
    bool? sceneCameraVisible,
    bool? isTimelinePlaying,
    bool? autoKeyEnabled,
    StyleEditScope? styleEditScope,
  }) {
    return EditorState(
      document: document ?? this.document,
      activeLayerId: activeLayerId ?? this.activeLayerId,
      shapes: shapes ?? this.shapes,
      activeTool: activeTool ?? this.activeTool,
      selectedShapeId: clearSelection
          ? null
          : (selectedShapeId ?? this.selectedShapeId),
      selectedShapeIds: clearSelection
          ? const []
          : (selectedShapeIds ?? this.selectedShapeIds),
      currentFrame: currentFrame ?? this.currentFrame,
      isLeftPanelOpen: isLeftPanelOpen ?? this.isLeftPanelOpen,
      leftPanelTab: leftPanelTab ?? this.leftPanelTab,
      shapeDrawKind: shapeDrawKind ?? this.shapeDrawKind,
      currentColor: currentColor ?? this.currentColor,
      isPanMode: isPanMode ?? this.isPanMode,
      currentBrush: currentBrush ?? this.currentBrush,
      brushSettings: brushSettings ?? this.brushSettings,
      eraserSettings: eraserSettings ?? this.eraserSettings,
      isToolPanelOpen: isToolPanelOpen ?? this.isToolPanelOpen,
      inProgressStroke: inProgressStroke != null
          ? List<PointVector>.unmodifiable(inProgressStroke)
          : this.inProgressStroke,
      palmRejectionEnabled: palmRejectionEnabled ?? this.palmRejectionEnabled,
      groupingEnabled: groupingEnabled ?? this.groupingEnabled,
      currentGroupId: currentGroupId ?? this.currentGroupId,
      transformGroupAsOne: transformGroupAsOne ?? this.transformGroupAsOne,
      selectionMode: selectionMode ?? this.selectionMode,
      shapeFillColor: shapeFillColor ?? this.shapeFillColor,
      pivotSnapEnabled: pivotSnapEnabled ?? this.pivotSnapEnabled,
      pivotSnapStrength: pivotSnapStrength ?? this.pivotSnapStrength,
      pivotFlipWithObject: pivotFlipWithObject ?? this.pivotFlipWithObject,
      strokeScaleWithShape: strokeScaleWithShape ?? this.strokeScaleWithShape,
      isInteractingWithCanvas:
          isInteractingWithCanvas ?? this.isInteractingWithCanvas,
      joystickControllerEnabled:
          joystickControllerEnabled ?? this.joystickControllerEnabled,
      joystickMode: joystickMode ?? this.joystickMode,
      camera: camera ?? this.camera,
      isProcessingHeavyOperation:
          isProcessingHeavyOperation ?? this.isProcessingHeavyOperation,
      groupNames: groupNames ?? this.groupNames,
      nodeEditState: nodeEditState ?? this.nodeEditState,
      mergePreviewShape: clearMergePreview
          ? null
          : (mergePreviewShape ?? this.mergePreviewShape),
      isLinkingMode: isLinkingMode ?? this.isLinkingMode,
      isSpatialDrawMode: isSpatialDrawMode ?? this.isSpatialDrawMode,
      spatialObjects: spatialObjects ?? this.spatialObjects,
      activeSpatialObjectId: clearActiveSpatialObjectId
          ? null
          : (activeSpatialObjectId ?? this.activeSpatialObjectId),
      linkingSourceShapeId: clearLinkingSource
          ? null
          : (linkingSourceShapeId ?? this.linkingSourceShapeId),
      pointModeState: pointModeState ?? this.pointModeState,
      sceneCamera: clearSceneCamera ? null : (sceneCamera ?? this.sceneCamera),
      sceneCameraVisible: sceneCameraVisible ?? this.sceneCameraVisible,
      isTimelinePlaying: isTimelinePlaying ?? this.isTimelinePlaying,
      autoKeyEnabled: autoKeyEnabled ?? this.autoKeyEnabled,
      styleEditScope: styleEditScope ?? this.styleEditScope,
    );
  }
}
