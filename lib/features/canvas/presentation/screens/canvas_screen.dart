import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/services/shape_merge_service.dart';
import 'package:animation_maker/features/canvas/presentation/models/point_mode_state.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brushes/brush_type.dart';
import 'package:animation_maker/features/canvas/presentation/services/node_edit_service.dart';
import 'package:animation_maker/features/canvas/presentation/services/shape_raster_paint_keys.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/brush_type_picker.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/secondary_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/core/widgets/color_picker_widget.dart';
import '../providers/canvas_notifier.dart';
import '../providers/image_providers.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/canvas_widget.dart';
import '../widgets/editor_app_bar.dart';
import '../widgets/joystick_controller.dart';
import '../widgets/layers_panel.dart';
import '../widgets/properties_panel.dart';
import '../widgets/shape_raster_paint_sheet.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/camera_properties_panel.dart';
import '../widgets/tool_settings_panel.dart';

class CanvasScreen extends ConsumerStatefulWidget {
  const CanvasScreen({super.key, this.documentId});

  final String? documentId;

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with WidgetsBindingObserver {
  static const double _sidePanelWidth = 220;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDocumentIfNeeded();
  }

  @override
  void didUpdateWidget(CanvasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _loadDocumentIfNeeded();
    }
  }

  void _loadDocumentIfNeeded() {
    final id = widget.documentId;
    if (id == null) return;
    Future.microtask(() {
      ref.read(editorViewModelProvider.notifier).loadDocument(id);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(editorViewModelProvider.notifier).saveDocument();
    }
  }

  /// Gets an approximate viewport size for zoom calculations.
  Size _getViewportSize(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Size(
      mediaQuery.size.width,
      mediaQuery.size.height - kToolbarHeight - 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.read(editorViewModelProvider.notifier);
    final viewportSize = _getViewportSize(context);

    return CallbackShortcuts(
      bindings: {
        // Ctrl/Cmd + 0: Reset zoom (fit to artboard)
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
            viewModel.fitCameraToArtboard(viewportSize),
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true): () =>
            viewModel.fitCameraToArtboard(viewportSize),
        // Ctrl/Cmd + 1: Actual size (100%)
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            viewModel.setCameraActualSize(),
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
            viewModel.setCameraActualSize(),
        // Ctrl/Cmd + =: Zoom in
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            viewModel.zoomCameraIn(viewportSize),
        const SingleActivator(LogicalKeyboardKey.equal, meta: true): () =>
            viewModel.zoomCameraIn(viewportSize),
        // Ctrl/Cmd + +: Zoom in (numpad)
        const SingleActivator(LogicalKeyboardKey.add, control: true): () =>
            viewModel.zoomCameraIn(viewportSize),
        const SingleActivator(LogicalKeyboardKey.add, meta: true): () =>
            viewModel.zoomCameraIn(viewportSize),
        // Ctrl/Cmd + -: Zoom out
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            viewModel.zoomCameraOut(viewportSize),
        const SingleActivator(LogicalKeyboardKey.minus, meta: true): () =>
            viewModel.zoomCameraOut(viewportSize),
      },
      child: Focus(
        autofocus: true,
        child: WillPopScope(
          onWillPop: () async {
            final vm = ref.read(editorViewModelProvider.notifier);
            vm.cancelDrawing();
            vm.cancelShapeDrawing();
            vm.setIsInteractingWithCanvas(false);
            await vm.saveDocument();
            return true;
          },
          child: Scaffold(
            appBar: const EditorAppBar(),
            body: SafeArea(
              child: Stack(
                children: [
                  const Positioned.fill(child: CanvasWidget()),
                  Consumer(
                    builder: (context, ref, _) {
                      final isOpen = ref.watch(
                        editorViewModelProvider.select(
                          (state) => state.isLeftPanelOpen,
                        ),
                      );
                      final tab = ref.watch(
                        editorViewModelProvider.select(
                          (state) => state.leftPanelTab,
                        ),
                      );
                      final notifier = ref.read(
                        editorViewModelProvider.notifier,
                      );
                      return Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: _sidePanelWidth,
                        child: IgnorePointer(
                          ignoring: !isOpen,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            offset: isOpen
                                ? Offset.zero
                                : const Offset(-1.04, 0),
                            child: Material(
                              elevation: 8,
                              color: AppColors.grey100,
                              child: Column(
                                children: [
                                  _LeftPanelTabs(
                                    activeTab: tab,
                                    onTabSelected: notifier.setLeftPanelTab,
                                  ),
                                  const Divider(height: 1),
                                  const Expanded(child: _LeftPanelBody()),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final isOpen = ref.watch(
                        editorViewModelProvider.select(
                          (state) => state.isToolPanelOpen,
                        ),
                      );
                      final isCameraMode = ref.watch(
                        editorViewModelProvider.select(
                          (state) => state.activeTool == EditorTool.camera,
                        ),
                      );
                      return Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: _sidePanelWidth,
                        child: IgnorePointer(
                          ignoring: !isOpen,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            offset: isOpen
                                ? Offset.zero
                                : const Offset(1.04, 0),
                            child: Material(
                              elevation: 8,
                              color: AppColors.grey50,
                              child: isCameraMode
                                  ? const CameraPropertiesPanel()
                                  : const ToolSettingsPanel(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const _SecondaryActionButtons(),
                  const Positioned(
                    right: 16,
                    bottom: 16,
                    child: JoystickController(),
                  ),
                  const Positioned(top: 56, right: 16, child: _CanvasZoomHud()),
                  Positioned(
                    top: 96,
                    right: 16,
                    child: _OriginSnapButton(viewportSize: viewportSize),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final isOpen = ref.watch(
                        editorViewModelProvider.select(
                          (state) => state.isLeftPanelOpen,
                        ),
                      );
                      final notifier = ref.read(
                        editorViewModelProvider.notifier,
                      );
                      final double buttonSize = 32;
                      final double openWidth = _sidePanelWidth;
                      return Positioned(
                        top: 12,
                        left: isOpen ? openWidth - (buttonSize / 2) : 0,
                        child: Material(
                          elevation: 2,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(12),
                          ),
                          color: AppColors.grey200,
                          child: SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              onPressed: notifier.toggleLayersPanel,
                              icon: Icon(
                                isOpen
                                    ? Icons.chevron_left
                                    : Icons.chevron_right,
                              ),
                              tooltip: isOpen
                                  ? 'Hide left panel'
                                  : 'Show left panel',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final isOpen = ref.watch(
                        editorViewModelProvider.select(
                          (state) => state.isToolPanelOpen,
                        ),
                      );
                      final notifier = ref.read(
                        editorViewModelProvider.notifier,
                      );
                      const double buttonSize = 32;
                      const double openWidth = _sidePanelWidth;
                      return Positioned(
                        top: 12,
                        right: isOpen ? openWidth - (buttonSize / 2) : 0,
                        child: Material(
                          elevation: 2,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(12),
                          ),
                          color: AppColors.grey200,
                          child: SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              onPressed: notifier.toggleToolPanel,
                              icon: Icon(
                                isOpen
                                    ? Icons.chevron_right
                                    : Icons.chevron_left,
                              ),
                              tooltip: isOpen
                                  ? 'Hide tool panel'
                                  : 'Show tool panel',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Processing indicator overlay
                  Consumer(
                    builder: (context, ref, _) {
                      final isProcessing = ref.watch(
                        editorViewModelProvider.select(
                          (state) => state.isProcessingHeavyOperation,
                        ),
                      );
                      if (!isProcessing) return const SizedBox.shrink();
                      return Container(
                        color: Colors.black38,
                        child: const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Processing shapes...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [TimelinePanel(), BottomActionBar()],
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasZoomHud extends ConsumerWidget {
  const _CanvasZoomHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(
      editorViewModelProvider.select((state) => state.camera.zoom),
    );
    final zoomPercent = (zoom * 100).round();
    final theme = Theme.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '$zoomPercent%',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _OriginSnapButton extends ConsumerWidget {
  const _OriginSnapButton({required this.viewportSize});

  final Size viewportSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(editorViewModelProvider.notifier);
    final camera = ref.watch(
      editorViewModelProvider.select((state) => state.camera),
    );
    return Material(
      elevation: 3,
      color: Colors.black.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(10),
      child: Tooltip(
        message: 'Tap: center on (0,0)\nHold: fit canvas',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => vm.setCamera(camera.copyWith(position: Offset.zero)),
          onLongPress: () => vm.fitCameraToArtboard(viewportSize),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(
              '0,0',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButtons extends ConsumerWidget {
  const _SecondaryActionButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(editorViewModelProvider.notifier);
    final state = ref.watch(editorViewModelProvider);

    final leftOpen = state.isLeftPanelOpen;
    final rightOpen = state.isToolPanelOpen;
    final isInteractingWithCanvas = ref.watch(
      editorViewModelProvider.select((s) => s.isInteractingWithCanvas),
    );

    final isSingleSelect = state.selectionMode == SelectionMode.single;
    final isMultiSelect = state.selectionMode != SelectionMode.single;
    final activeTool = state.activeTool;
    final hasSingleSelection = state.selectedShapeId != null;
    final hasMultiSelection = state.selectedShapeIds.isNotEmpty;
    final isNodeEditMode = state.isNodeEditMode;
    bool show = false;
    final List<Widget> buttons = [];

    // Node edit mode has its own exclusive bar
    if (isNodeEditMode) {
      show = true;

      final nodeState = state.nodeEditState;
      final selectedShape = state.selectedShape;
      final showInfluenceSlider = nodeState.useWeightedEdit &&
          selectedShape != null &&
          selectedShape.kind == ShapeKind.freehand;

      buttons.addAll([
        // Influence radius slider for freehand weighted edit
        if (showInfluenceSlider) ...[
          _InfluenceRadiusControl(
            value: nodeState.weightedInfluenceRadius,
            totalArcLength: nodeState.totalArcLength,
            onChanged: (value) {
              vm.updateNodeEditState(
                nodeState.copyWith(weightedInfluenceRadius: value),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
        // Action buttons
        ActionBarButton(
          icon: Icons.select_all,
          label: 'All',
          tooltip: 'Select all nodes',
          onPressed: vm.selectAllNodes,
        ),
        const SizedBox(width: 6),
        ActionBarButton(
          icon: Icons.close,
          label: 'Exit',
          tooltip: 'Exit node edit mode',
          onPressed: vm.exitNodeEditMode,
        ),
      ]);
    }
    // Multi-select mode has its own exclusive bar
    else if (isMultiSelect) {
      if (hasMultiSelection) {
        show = true;
        final shapes = state.shapes;
        final selectedShapes = state.selectedShapeIds
            .map((id) {
              try {
                return shapes.firstWhere((s) => s.id == id);
              } catch (e) {
                return null;
              }
            })
            .where((s) => s != null)
            .cast<Shape>()
            .toList();

        final canMerge = selectedShapes.length >= 2;
        final canGroup = selectedShapes.length >= 2;
        final canUngroup =
            hasMultiSelection && selectedShapes.any((s) => s.groupId != null);

        // Check if shapes are on same layer for merge
        final canMergeSameLayer = canMerge && vm.selectedShapesOnSameLayer();
        buttons.addAll([
          _MergeButton(
            isEnabled: canMergeSameLayer,
            disabledReason: canMerge
                ? (canMergeSameLayer ? null : 'Shapes are on different layers')
                : 'Select 2+ shapes',
            onMerge: (mode) async {
              final result = await vm.mergeSelectedIds(mode: mode);
              if (context.mounted) {
                if (!result.isSuccess) {
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                } else if (result.type == MergeResultType.partialSuccess) {
                  // Show warning that some shapes were skipped
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
          ActionBarButton(
            icon: Icons.group_work_outlined,
            label: 'Group',
            tooltip: 'Group selected shapes',
            isEnabled: canGroup,
            onPressed: vm.groupSelection,
          ),
          const SizedBox(width: 8),
          ActionBarButton(
            icon: Icons.layers_clear_outlined,
            label: 'Ungroup',
            tooltip: 'Ungroup selected shapes',
            isEnabled: canUngroup,
            onPressed: vm.ungroupSelection,
          ),
          const SizedBox(width: 8),
          ActionBarButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            tooltip: 'Delete',
            isEnabled: hasMultiSelection,
            onPressed: vm.deleteSelectedIds,
          ),
        ]);
      }
    }
    // Single-select mode is the default and can host tool-specific or selection-specific buttons
    else if (isSingleSelect) {
      // Tool-specific buttons (visible even without a selection)
      if (activeTool == EditorTool.brush) {
        show = true;
        buttons.addAll([
          _DraggableSizeButton(
            label: 'Size',
            value: state.brushSettings[state.currentBrush]!.thickness,
            onChanged: vm.setBrushThickness,
          ),
          const SizedBox(width: 8),
          _DraggableOpacityButton(
            label: 'Opacity',
            value: state.brushSettings[state.currentBrush]!.opacity,
            onChanged: vm.setBrushOpacity,
          ),
          const SizedBox(width: 8),
          _BrushColorButton(
            currentColor: state.currentColor,
            recentColors: state.document.recentColors
                .map((value) => Color(value))
                .toList(growable: false),
            onPreviewChanged: vm.setCurrentColorPreview,
            onColorCommitted: vm.setCurrentColor,
          ),
          const SizedBox(width: 8),
          _BrushTypeButton(
            currentBrush: state.currentBrush,
            onBrushChanged: vm.setBrushType,
            palmRejectionEnabled: state.palmRejectionEnabled,
            onTogglePalmRejection: vm.togglePalmRejection,
          ),
          const SizedBox(width: 8),
          ActionBarButton(
            icon: Icons.account_tree_outlined,
            label: 'Spatial',
            tooltip: state.isSpatialDrawMode
                ? 'Finish spatial drawing'
                : 'Draw as spatial object',
            isActive: state.isSpatialDrawMode,
            onPressed: vm.toggleSpatialDrawMode,
          ),
        ]);
      } else if (activeTool == EditorTool.eraser) {
        show = true;
        buttons.addAll([
          _DraggableSizeButton(
            label: 'Size',
            value: state.eraserSettings.thickness,
            onChanged: vm.setEraserThickness,
          ),
          const SizedBox(width: 8),
          _DraggableOpacityButton(
            label: 'Opacity',
            value: state.eraserSettings.opacity,
            onChanged: vm.setEraserOpacity,
          ),
          const SizedBox(width: 8),
          const ActionBarButton(
            icon: Icons.blur_on,
            label: 'Fade',
            tooltip: 'Fade (coming soon)',
            isEnabled: false,
          ),
          const SizedBox(width: 8),
          const ActionBarButton(
            icon: Icons.category,
            label: 'Type',
            tooltip: 'Eraser Type (coming soon)',
            isEnabled: false,
          ),
        ]);
      } else if (activeTool == EditorTool.shape &&
          state.shapeDrawKind == ShapeKind.pointPath &&
          state.pointModeState.isActive) {
        // Point mode drawing buttons
        show = true;
        final pointState = state.pointModeState;

        buttons.addAll([
          // Connection type: Straight
          ActionBarButton(
            icon: Icons.show_chart,
            label: 'Straight',
            tooltip: 'Connect with straight lines',
            isActive: pointState.connectionType == PointConnectionType.straight,
            isEnabled: pointState.canConnect,
            onPressed: pointState.canConnect
                ? () => vm.setPointModeConnectionType(
                    PointConnectionType.straight,
                  )
                : null,
          ),
          const SizedBox(width: 6),
          // Connection type: Curved
          ActionBarButton(
            icon: Icons.gesture,
            label: 'Curved',
            tooltip: 'Connect with smooth Bezier curves',
            isActive: pointState.connectionType == PointConnectionType.curved,
            isEnabled: pointState.canConnect,
            onPressed: pointState.canConnect
                ? () =>
                      vm.setPointModeConnectionType(PointConnectionType.curved)
                : null,
          ),
          const SizedBox(width: 12),
          // Close shape toggle
          ActionBarButton(
            icon: pointState.isClosed
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            label: 'Close',
            tooltip: 'Close the shape (connect last to first point)',
            isActive: pointState.isClosed,
            isEnabled: pointState.canClose,
            onPressed: pointState.canClose ? vm.togglePointModeClosed : null,
          ),
          const SizedBox(width: 12),
          // Undo last point
          ActionBarButton(
            icon: Icons.undo,
            label: 'Undo Pt',
            tooltip: 'Remove last placed point',
            isEnabled: pointState.hasPoints,
            onPressed: pointState.hasPoints
                ? vm.removeLastPointModePoint
                : null,
          ),
          const SizedBox(width: 6),
          // Done/Finalize
          ActionBarButton(
            icon: Icons.check,
            label: 'Done',
            tooltip: 'Finalize shape',
            isEnabled: pointState.canConnect,
            onPressed: pointState.canConnect ? vm.finalizePointMode : null,
          ),
          const SizedBox(width: 6),
          // Cancel
          ActionBarButton(
            icon: Icons.close,
            label: 'Cancel',
            tooltip: 'Cancel point drawing',
            onPressed: vm.exitPointMode,
          ),
        ]);
      }

      // Selection-specific buttons (only in select tool when a shape is selected)
      final showSelectionButtons =
          hasSingleSelection && activeTool == EditorTool.select;
      if (showSelectionButtons) {
        if (buttons.isNotEmpty) {
          buttons.add(const SizedBox(width: 6));
        }

        Shape? selectedShape;
        final matching = state.shapes.where(
          (s) => s.id == state.selectedShapeId,
        );
        if (matching.isNotEmpty) {
          selectedShape = matching.first;
        }
        final isInGroup = selectedShape?.groupId != null;
        final selectedSpatialId = selectedShape?.spatialObjectId;
        final isSpatialSelection = selectedSpatialId != null;
        final nodeEditService = const NodeEditService();
        final canEditNodes =
            selectedShape != null &&
            nodeEditService.isNodeEditable(selectedShape);
        final canConvertToPath =
            selectedShape != null &&
            nodeEditService.canConvertToPath(selectedShape);

        // Color and stroke width controls for selected shape
        if (selectedShape != null) {
          final selectedShapeValue = selectedShape;
          buttons.addAll([
            _SelectedShapeColorButton(
              currentColor: selectedShapeValue.strokeColor,
              recentColors: state.document.recentColors
                  .map((value) => Color(value))
                  .toList(growable: false),
              onChanged: (color) => vm.updateSelectedStroke(strokeColor: color),
              onColorCommitted: vm.recordProjectColor,
            ),
            const SizedBox(width: 6),
            _SelectedShapeStrokeButton(
              strokeWidth: selectedShapeValue.strokeWidth,
              onChanged: (width) => vm.updateSelectedStroke(strokeWidth: width),
            ),
            const SizedBox(width: 6),
            _SelectedShapeOpacityButton(
              opacity: selectedShapeValue.opacity,
              onChanged: vm.updateSelectedOpacity,
            ),
            const SizedBox(width: 6),
            ActionBarButton(
              icon: Icons.brush_outlined,
              label: 'Paint',
              tooltip: 'Paint raster on shape',
              onPressed: () async {
                final imageService = ref.read(imageServiceProvider);
                final existingPath = _shapeRasterPaintPath(selectedShapeValue);
                final existingImage = existingPath == null
                    ? null
                    : (imageService.getCachedImage(existingPath) ??
                          await imageService.loadImage(existingPath));
                if (!context.mounted) return;

                final pngBytes = await showShapeRasterPaintSheet(
                  context: context,
                  shape: selectedShapeValue,
                  existingRasterImage: existingImage,
                  recentColors: vm.projectRecentColors,
                  onColorUsed: vm.recordProjectColor,
                );
                if (pngBytes == null || !context.mounted) return;

                final relativePath = await imageService.persistImageBytes(
                  pngBytes,
                  filePrefix: 'shape_paint',
                  extension: '.png',
                );
                if (!context.mounted) return;
                vm.setShapeRasterPaintPath(selectedShapeValue.id, relativePath);
              },
            ),
            const SizedBox(width: 6),
          ]);
        }

        // Unified transform button - only show for grouped shapes
        if (isInGroup) {
          buttons.addAll([
            ActionBarButton(
              icon: state.transformGroupAsOne
                  ? Icons.center_focus_strong
                  : Icons.center_focus_weak,
              label: 'Unified',
              tooltip: state.transformGroupAsOne
                  ? 'Transforms as one'
                  : 'Transforms individually',
              onPressed: vm.toggleTransformGroupAsOne,
            ),
            const SizedBox(width: 6),
          ]);
        }

        // Spatial objects use brush-based editing, not node editing.
        if (isSpatialSelection) {
          buttons.addAll([
            const SizedBox(width: 6),
            ActionBarButton(
              icon: Icons.edit_outlined,
              label: 'Edit',
              tooltip: 'Add more strokes to this spatial object',
              onPressed: () {
                final started = vm.startEditingSpatialObject(selectedSpatialId);
                if (!started && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to start spatial edit mode'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ]);
        } else {
          // Edit Nodes button - for node-editable shapes, or convert-and-edit for rect/ellipse
          final hasMultipleContours =
              selectedShape != null &&
              nodeEditService.hasMultipleContours(selectedShape);

          buttons.addAll([
            const SizedBox(width: 6),
            ActionBarButton(
              icon: Icons.timeline,
              label: canConvertToPath ? 'To Path' : 'Nodes',
              tooltip: canEditNodes
                  ? (hasMultipleContours
                        ? 'Edit nodes (only first contour editable)'
                        : 'Edit nodes')
                  : canConvertToPath
                  ? 'Convert to editable path'
                  : 'Select a shape to edit nodes',
              isEnabled: canEditNodes || canConvertToPath,
              onPressed: canEditNodes
                  ? vm.enterNodeEditMode
                  : canConvertToPath
                  ? vm.convertAndEditNodes
                  : null,
            ),
          ]);

          // Explode Contours button - for multi-contour shapes
          if (hasMultipleContours) {
            final contourCount = nodeEditService.getContourCount(selectedShape);
            buttons.addAll([
              const SizedBox(width: 6),
              ActionBarButton(
                icon: Icons.call_split,
                label: 'Split ($contourCount)',
                tooltip: 'Split into $contourCount separate shapes',
                onPressed: () {
                  final success = vm.explodeSelectedContours();
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Split into $contourCount separate shapes',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ]);
          }
        }

        if (isInGroup) {
          buttons.addAll([
            const SizedBox(width: 6),
            ActionBarButton(
              icon: Icons.layers_clear_outlined,
              label: 'Ungroup',
              tooltip: 'Remove from group',
              onPressed: vm.ungroupSelection,
            ),
          ]);
        }

        // Parent-child hierarchy buttons
        final hasParent = selectedShape?.parentId != null;
        final isLinkingMode = state.isLinkingMode;

        buttons.addAll([
          const SizedBox(width: 6),
          ActionBarButton(
            icon: isLinkingMode ? Icons.link_off : Icons.link,
            label: isLinkingMode ? 'Cancel' : 'Link',
            tooltip: isLinkingMode
                ? 'Cancel linking'
                : 'Link to parent (tap another shape)',
            isActive: isLinkingMode,
            onPressed: isLinkingMode ? vm.exitLinkingMode : vm.enterLinkingMode,
          ),
        ]);

        if (hasParent) {
          buttons.addAll([
            const SizedBox(width: 6),
            ActionBarButton(
              icon: Icons.link_off,
              label: 'Unlink',
              tooltip: 'Unlink from parent',
              onPressed: vm.unlinkFromParent,
            ),
          ]);
        }

        buttons.addAll([
          const SizedBox(width: 6),
          ActionBarButton(
            icon: Icons.content_copy,
            label: 'Duplicate',
            tooltip: 'Duplicate',
            onPressed: vm.duplicateSelected,
          ),
          const SizedBox(width: 6),
          ActionBarButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            tooltip: 'Delete',
            onPressed: vm.deleteSelected,
          ),
          const SizedBox(width: 6),
          ActionBarButton(
            icon: Icons.flip,
            label: 'Flip H',
            tooltip: 'Flip horizontal',
            onPressed: vm.flipSelectedHorizontal,
          ),
          const SizedBox(width: 6),
          ActionBarButton(
            icon: Icons.flip_camera_android,
            label: 'Flip V',
            tooltip: 'Flip vertical',
            onPressed: vm.flipSelectedVertical,
          ),
          const SizedBox(width: 6),
          ActionBarButton(
            icon: Icons.skip_previous,
            label: 'Prev',
            tooltip: 'Select previous shape',
            isEnabled: state.shapes.isNotEmpty,
            onPressed: state.shapes.isNotEmpty ? vm.selectPreviousShape : null,
          ),
          const SizedBox(width: 6),
          ActionBarButton(
            icon: Icons.skip_next,
            label: 'Next',
            tooltip: 'Select next shape',
            isEnabled: state.shapes.isNotEmpty,
            onPressed: state.shapes.isNotEmpty ? vm.selectNextShape : null,
          ),
        ]);
      } else if (activeTool == EditorTool.select) {
        if (buttons.isNotEmpty) {
          buttons.add(const SizedBox(width: 6));
        }
        buttons.addAll([
          ActionBarButton(
            icon: Icons.skip_previous,
            label: 'Prev',
            tooltip: 'Select previous shape',
            isEnabled: state.shapes.isNotEmpty,
            onPressed: state.shapes.isNotEmpty ? vm.selectPreviousShape : null,
          ),
          const SizedBox(width: 6),
          ActionBarButton(
            icon: Icons.skip_next,
            label: 'Next',
            tooltip: 'Select next shape',
            isEnabled: state.shapes.isNotEmpty,
            onPressed: state.shapes.isNotEmpty ? vm.selectNextShape : null,
          ),
        ]);
      }

      if (buttons.isNotEmpty) {
        show = true;
      }
    }

    final shouldHideForInteraction =
        isInteractingWithCanvas && state.inProgressStroke.isNotEmpty;
    return SecondaryActionBar(
      show: show && !shouldHideForInteraction,
      leftOpen: leftOpen,
      rightOpen: rightOpen,
      children: buttons,
    );
  }
}

String? _shapeRasterPaintPath(Shape shape) {
  final metadata = shape.metadata;
  if (metadata == null) return null;
  final raw = metadata[kShapeRasterPaintPathKey];
  if (raw is String && raw.isNotEmpty) {
    return raw;
  }
  return null;
}

class _LeftPanelTabs extends StatelessWidget {
  const _LeftPanelTabs({required this.activeTab, required this.onTabSelected});

  final LeftPanelTab activeTab;
  final ValueChanged<LeftPanelTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.grey100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Layers',
              isActive: activeTab == LeftPanelTab.layers,
              onPressed: () => onTabSelected(LeftPanelTab.layers),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TabButton(
              label: 'Selection',
              isActive: activeTab == LeftPanelTab.selection,
              onPressed: () => onTabSelected(LeftPanelTab.selection),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: isActive
            ? theme.colorScheme.primary.withOpacity(0.12)
            : AppColors.white,
        foregroundColor: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      onPressed: onPressed,
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }
}

class _LeftPanelBody extends ConsumerWidget {
  const _LeftPanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(
      editorViewModelProvider.select((state) => state.leftPanelTab),
    );
    switch (tab) {
      case LeftPanelTab.layers:
        return const LayersPanel();
      case LeftPanelTab.selection:
        return const PropertiesPanel();
    }
  }
}

class _LiveUpdatingSizeOverlay extends ConsumerWidget {
  const _LiveUpdatingSizeOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(
      editorViewModelProvider.select((s) => s.activeTool),
    );
    final thickness = ref.watch(
      editorViewModelProvider.select(
        (s) => activeTool == EditorTool.eraser
            ? s.eraserSettings.thickness
            : s.brushSettings[s.currentBrush]!.thickness,
      ),
    );

    final displayValue = thickness.round().toDouble();
    final displaySize = displayValue.clamp(20.0, 300.0);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: IgnorePointer(
          child: Container(
            width: displaySize,
            height: displaySize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
            ),
            child: Center(
              child: Text(
                thickness.round().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveUpdatingOpacityOverlay extends ConsumerWidget {
  const _LiveUpdatingOpacityOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(
      editorViewModelProvider.select((s) => s.activeTool),
    );
    final opacity = ref.watch(
      editorViewModelProvider.select(
        (s) => activeTool == EditorTool.eraser
            ? s.eraserSettings.opacity
            : s.brushSettings[s.currentBrush]!.opacity,
      ),
    );

    final displayValue = (opacity * 100).round().toDouble();
    final displaySize = displayValue.clamp(20.0, 300.0);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: IgnorePointer(
          child: Container(
            width: displaySize,
            height: displaySize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
            ),
            child: Center(
              child: Text(
                '${displayValue.round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraggableSizeButton extends ConsumerStatefulWidget {
  const _DraggableSizeButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  ConsumerState<_DraggableSizeButton> createState() =>
      _DraggableSizeButtonState();
}

class _DraggableSizeButtonState extends ConsumerState<_DraggableSizeButton> {
  OverlayEntry? _overlayEntry;

  void _showOverlay(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder: (context) => const _LiveUpdatingSizeOverlay(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onPanStart: (details) {
        _showOverlay(context);
      },
      onPanUpdate: (details) {
        final delta = details.delta.dx - details.delta.dy;
        final intStep = delta > 0 ? 1 : (delta < 0 ? -1 : 0);
        final newValue = (widget.value + intStep).roundToDouble();
        if (newValue != widget.value) {
          widget.onChanged(newValue);
        }
      },
      onPanEnd: (details) {
        _removeOverlay();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '${widget.label}: ${widget.value.round()}\nDrag to change',
            onPressed: () {},
            icon: Icon(
              Icons.panorama_fish_eye,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '${widget.label}: ${widget.value.round()}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableOpacityButton extends ConsumerStatefulWidget {
  const _DraggableOpacityButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  ConsumerState<_DraggableOpacityButton> createState() =>
      _DraggableOpacityButtonState();
}

class _DraggableOpacityButtonState
    extends ConsumerState<_DraggableOpacityButton> {
  OverlayEntry? _overlayEntry;

  void _showOverlay(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder: (context) => const _LiveUpdatingOpacityOverlay(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onPanStart: (details) {
        _showOverlay(context);
      },
      onPanUpdate: (details) {
        final delta = details.delta.dx - details.delta.dy;
        const sensitivity = 0.005;
        final newValue = widget.value + delta * sensitivity;
        widget.onChanged(newValue.clamp(0.0, 1.0));
      },
      onPanEnd: (details) {
        _removeOverlay();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip:
                '${widget.label}: ${(widget.value * 100).toStringAsFixed(0)}%\nDrag to change',
            onPressed: () {},
            icon: Icon(
              Icons.opacity,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '${(widget.value * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrushColorButton extends ConsumerWidget {
  const _BrushColorButton({
    required this.currentColor,
    required this.recentColors,
    required this.onPreviewChanged,
    required this.onColorCommitted,
  });

  final Color currentColor;
  final List<Color> recentColors;
  final ValueChanged<Color> onPreviewChanged;
  final ValueChanged<Color> onColorCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Brush Color',
          onPressed: () async {
            final initial = currentColor;
            final picked = await showAdaptiveColorPicker(
              context: context,
              initialColor: currentColor,
              recentColors: recentColors,
              onColorChanged: onPreviewChanged,
            );
            if (picked == null) {
              onPreviewChanged(initial);
              return;
            }
            onColorCommitted(picked);
          },
          icon: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentColor,
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
        ),
        Text(
          'Color',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _BrushTypeButton extends ConsumerWidget {
  const _BrushTypeButton({
    required this.currentBrush,
    required this.onBrushChanged,
    required this.palmRejectionEnabled,
    required this.onTogglePalmRejection,
  });

  final BrushType currentBrush;
  final ValueChanged<BrushType> onBrushChanged;
  final bool palmRejectionEnabled;
  final VoidCallback onTogglePalmRejection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brushLabel = brushDefinition(currentBrush).label;
    final brushIcon = brushDefinition(currentBrush).icon;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Brush Type ($brushLabel)',
          onPressed: () async {
            final picked = await showBrushTypePicker(
              context: context,
              current: currentBrush,
              palmRejectionEnabled: palmRejectionEnabled,
              onTogglePalmRejection: onTogglePalmRejection,
            );
            if (picked != null) {
              onBrushChanged(picked);
            }
          },
          icon: Icon(brushIcon, size: 20, color: theme.colorScheme.onSurface),
        ),
        Text(
          'Type',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _SelectedShapeColorButton extends StatelessWidget {
  const _SelectedShapeColorButton({
    required this.currentColor,
    required this.recentColors,
    required this.onChanged,
    this.onColorCommitted,
  });

  final Color currentColor;
  final List<Color> recentColors;
  final ValueChanged<Color> onChanged;
  final ValueChanged<Color>? onColorCommitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Shape Color',
          onPressed: () async {
            final initial = currentColor;
            final picked = await showAdaptiveColorPicker(
              context: context,
              initialColor: currentColor,
              recentColors: recentColors,
              onColorChanged: onChanged,
            );
            if (picked == null) {
              onChanged(initial);
              return;
            }
            onChanged(picked);
            onColorCommitted?.call(picked);
          },
          icon: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentColor,
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        Text(
          'Color',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _SelectedShapeStrokeButton extends StatefulWidget {
  const _SelectedShapeStrokeButton({
    required this.strokeWidth,
    required this.onChanged,
  });

  final double strokeWidth;
  final ValueChanged<double> onChanged;

  @override
  State<_SelectedShapeStrokeButton> createState() =>
      _SelectedShapeStrokeButtonState();
}

class _SelectedShapeStrokeButtonState
    extends State<_SelectedShapeStrokeButton> {
  OverlayEntry? _overlayEntry;

  void _showOverlay(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder: (context) =>
          _StrokeWidthOverlay(strokeWidth: widget.strokeWidth),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onPanStart: (details) {
        _showOverlay(context);
      },
      onPanUpdate: (details) {
        final delta = details.delta.dx - details.delta.dy;
        final intStep = delta > 0 ? 0.5 : (delta < 0 ? -0.5 : 0);
        final newValue = (widget.strokeWidth + intStep).clamp(0.5, 100.0);
        if (newValue != widget.strokeWidth) {
          widget.onChanged(newValue);
        }
      },
      onPanEnd: (details) {
        _removeOverlay();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip:
                'Stroke: ${widget.strokeWidth.toStringAsFixed(1)}\nDrag to change',
            onPressed: () {},
            icon: Icon(
              Icons.line_weight,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            widget.strokeWidth.toStringAsFixed(1),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedShapeOpacityButton extends StatefulWidget {
  const _SelectedShapeOpacityButton({
    required this.opacity,
    required this.onChanged,
  });

  final double opacity;
  final ValueChanged<double> onChanged;

  @override
  State<_SelectedShapeOpacityButton> createState() =>
      _SelectedShapeOpacityButtonState();
}

class _SelectedShapeOpacityButtonState
    extends State<_SelectedShapeOpacityButton> {
  OverlayEntry? _overlayEntry;

  void _showOverlay(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder: (context) =>
          _SelectedShapeOpacityOverlay(opacity: widget.opacity),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacityPercent = (widget.opacity * 100).round();
    return GestureDetector(
      onPanStart: (_) => _showOverlay(context),
      onPanUpdate: (details) {
        final delta = details.delta.dx - details.delta.dy;
        const sensitivity = 0.005;
        final newValue = (widget.opacity + delta * sensitivity).clamp(0.0, 1.0);
        if (newValue != widget.opacity) {
          widget.onChanged(newValue);
        }
      },
      onPanEnd: (_) => _removeOverlay(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Opacity: $opacityPercent%\nDrag to change',
            onPressed: () {},
            icon: Icon(
              Icons.opacity,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '$opacityPercent%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrokeWidthOverlay extends StatelessWidget {
  const _StrokeWidthOverlay({required this.strokeWidth});

  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final displayValue = strokeWidth.clamp(20.0, 300.0);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: IgnorePointer(
          child: Container(
            width: displayValue,
            height: displayValue,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
            ),
            child: Center(
              child: Text(
                strokeWidth.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedShapeOpacityOverlay extends StatelessWidget {
  const _SelectedShapeOpacityOverlay({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final percent = (opacity * 100).round();
    final displaySize = percent.toDouble().clamp(20.0, 300.0);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: IgnorePointer(
          child: Container(
            width: displaySize,
            height: displaySize,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
            ),
            child: Center(
              child: Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Button with dropdown for selecting merge mode.
class _MergeButton extends StatelessWidget {
  const _MergeButton({
    required this.isEnabled,
    required this.onMerge,
    this.disabledReason,
  });

  final bool isEnabled;
  final String? disabledReason;
  final void Function(MergeMode mode) onMerge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooltip = isEnabled
        ? 'Select merge mode'
        : 'Merge: ${disabledReason ?? "Not available"}';

    final iconColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.disabledColor;
    final textColor = isEnabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
        : theme.disabledColor;

    return PopupMenuButton<MergeMode>(
      enabled: isEnabled,
      tooltip: tooltip,
      onSelected: onMerge,
      offset: const Offset(0, -220),
      itemBuilder: (context) => MergeMode.values.map((mode) {
        return PopupMenuItem<MergeMode>(
          value: mode,
          child: Row(
            children: [
              Icon(_iconForMode(mode), size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    mode.description,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
      // Use a custom child that doesn't have its own onPressed
      // so the PopupMenuButton can handle the tap
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.merge_type, size: 20, color: iconColor),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 14, color: iconColor),
                ],
              ),
            ),
            Text(
              'Merge',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForMode(MergeMode mode) {
    switch (mode) {
      case MergeMode.union:
        return Icons.add_box_outlined;
      case MergeMode.intersect:
        return Icons.filter_none;
      case MergeMode.difference:
        return Icons.remove_circle_outline;
      case MergeMode.xor:
        return Icons.swap_horiz;
      case MergeMode.reverseDifference:
        return Icons.flip_to_back;
    }
  }
}

/// Compact slider control for adjusting weighted drag influence radius
/// in node edit mode for freehand strokes.
class _InfluenceRadiusControl extends StatelessWidget {
  const _InfluenceRadiusControl({
    required this.value,
    required this.totalArcLength,
    required this.onChanged,
  });

  final double value;
  final double totalArcLength;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minRadius = (totalArcLength * 0.05).clamp(20.0, 80.0);
    final maxRadius = (totalArcLength * 1.0).clamp(100.0, 1200.0);
    final clamped = value.clamp(minRadius, maxRadius);
    final percent = totalArcLength > 0
        ? ((clamped / totalArcLength) * 100).round()
        : 0;

    final String sizeLabel;
    if (percent <= 15) {
      sizeLabel = 'Tight';
    } else if (percent <= 40) {
      sizeLabel = 'Med';
    } else if (percent <= 70) {
      sizeLabel = 'Wide';
    } else {
      sizeLabel = 'Full';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.adjust,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 80,
                height: 20,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.onSurface
                        .withValues(alpha: 0.15),
                    thumbColor: theme.colorScheme.primary,
                  ),
                  child: Slider(
                    value: clamped,
                    min: minRadius,
                    max: maxRadius,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
          Text(
            sizeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
