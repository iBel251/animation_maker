import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/core/widgets/color_picker_widget.dart';
import 'package:animation_maker/core/constants/app_colors.dart';
import '../models/editor_tool.dart';
import '../painting/brushes/brush_type.dart';
import '../providers/canvas_notifier.dart';
import 'brush_type_picker.dart';
import 'editor_menu_sheet.dart';
import 'selection_mode_picker.dart';
import 'shape_type_picker.dart';

class EditorAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const EditorAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<EditorAppBar> createState() => _EditorAppBarState();
}

class _EditorAppBarState extends ConsumerState<EditorAppBar> {
  final ScrollController _scrollController = ScrollController();

  /// Gets an approximate viewport size for zoom calculations.
  /// Uses MediaQuery since the actual canvas widget size isn't available here.
  Size _getViewportSize(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Approximate canvas viewport (excluding app bar and other UI)
    return Size(
      mediaQuery.size.width,
      mediaQuery.size.height - kToolbarHeight - 100, // Rough estimate
    );
  }

  @override
  void initState() {
    super.initState();
    // Ensure scroll starts at the left (position 0) after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTool = ref.watch(
      editorViewModelProvider.select((state) => state.activeTool),
    );
    final currentColor = ref.watch(
      editorViewModelProvider.select((state) => state.currentColor),
    );
    final recentColors = ref.watch(
      editorViewModelProvider.select(
        (state) => state.document.recentColors
            .map((value) => Color(value))
            .toList(growable: false),
      ),
    );
    final palmRejectionEnabled = ref.watch(
      editorViewModelProvider.select((state) => state.palmRejectionEnabled),
    );
    final shapeDrawKind = ref.watch(
      editorViewModelProvider.select((state) => state.shapeDrawKind),
    );
    final selectionMode = ref.watch(
      editorViewModelProvider.select((state) => state.selectionMode),
    );
    final isPanMode = ref.watch(
      editorViewModelProvider.select((state) => state.isPanMode),
    );
    final currentBrush = ref.watch(
      editorViewModelProvider.select((state) => state.currentBrush),
    );
    final documentTitle = ref.watch(
      editorViewModelProvider.select((state) => state.document.title),
    );
    final viewModel = ref.read(editorViewModelProvider.notifier);

    Widget toolButton({
      required EditorTool tool,
      required Widget icon,
      required String tooltip,
      Future<void> Function()? onActivePress,
    }) {
      final theme = Theme.of(context);
      final isActive = activeTool == tool;
      final fg = isActive
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withOpacity(0.45);
      final bg = isActive
          ? theme.colorScheme.primary.withOpacity(0.12)
          : AppColors.transparent;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () async {
            if (!isActive) {
              viewModel.setActiveTool(tool);
            } else {
              if (onActivePress != null) {
                await onActivePress();
              }
            }
          },
          icon: icon,
          tooltip: tooltip,
          color: fg,
        ),
      );
    }

    Widget shapeButton() {
      final theme = Theme.of(context);
      final isActive = activeTool == EditorTool.shape;
      final fg = isActive
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withOpacity(0.45);
      final bg = isActive
          ? theme.colorScheme.primary.withOpacity(0.12)
          : AppColors.transparent;
      IconData icon;
      switch (shapeDrawKind) {
        case ShapeKind.rectangle:
          icon = Icons.crop_square;
          break;
        case ShapeKind.ellipse:
          icon = Icons.circle_outlined;
          break;
        case ShapeKind.line:
          icon = Icons.show_chart;
          break;
        case ShapeKind.polygon:
          icon = Icons.change_history;
          break;
        case ShapeKind.freehand:
          icon = Icons.brush;
          break;
        case ShapeKind.pointPath:
          icon = Icons.timeline;
          break;
        case ShapeKind.image:
          icon = Icons.image;
          break;
      }

      final label = shapeOptionFor(shapeDrawKind).label;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          tooltip: isActive ? 'Shape ($label)' : 'Shape',
          icon: Icon(icon),
          color: fg,
          onPressed: () async {
            if (activeTool != EditorTool.shape) {
              viewModel.setActiveTool(EditorTool.shape);
              return;
            }
            final picked = await showShapeTypePicker(
              context: context,
              current: shapeDrawKind,
            );
            if (picked != null) {
              viewModel.setShapeDrawKind(picked);
            }
          },
        ),
      );
    }

    Widget brushButton() {
      final theme = Theme.of(context);
      final isActive = activeTool == EditorTool.brush;
      final fg = isActive
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withOpacity(0.45);
      final bg = isActive
          ? theme.colorScheme.primary.withOpacity(0.12)
          : AppColors.transparent;
      final brushLabel = brushDefinition(currentBrush).label;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          tooltip: isActive ? 'Brush ($brushLabel)' : 'Brush',
          icon: const Icon(Icons.brush),
          color: fg,
          onPressed: () async {
            if (activeTool != EditorTool.brush) {
              viewModel.setActiveTool(EditorTool.brush);
              return;
            }
            final picked = await showBrushTypePicker(
              context: context,
              current: currentBrush,
              palmRejectionEnabled: palmRejectionEnabled,
              onTogglePalmRejection: viewModel.togglePalmRejection,
            );
            if (picked != null) {
              viewModel.setBrushType(picked);
            }
          },
        ),
      );
    }

    final actionItems = <Widget>[
      // Zoom controls (percentage moved to floating canvas HUD)
      _ZoomControls(
        onZoomIn: () => viewModel.zoomCameraIn(_getViewportSize(context)),
        onZoomOut: () => viewModel.zoomCameraOut(_getViewportSize(context)),
        onResetZoom: () =>
            viewModel.fitCameraToArtboard(_getViewportSize(context)),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: isPanMode ? 'Pan/Zoom mode (on)' : 'Pan/Zoom mode (off)',
        onPressed: viewModel.togglePanMode,
        color: isPanMode
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        icon: const Icon(Icons.open_with),
      ),
      IconButton(
        tooltip: 'Pick color',
        onPressed: () async {
          final initial = currentColor;
          final picked = await showAdaptiveColorPicker(
            context: context,
            initialColor: currentColor,
            recentColors: recentColors,
            onColorChanged: viewModel.setCurrentColorPreview,
          );
          if (picked == null) {
            viewModel.setCurrentColorPreview(initial);
            return;
          }
          viewModel.setCurrentColor(picked);
        },
        icon: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentColor,
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ),
      ),
      brushButton(),
      shapeButton(),
      toolButton(
        tool: EditorTool.eraser,
        icon: const _EraserIcon(),
        tooltip: 'Eraser',
      ),
      toolButton(
        tool: EditorTool.fill,
        icon: const Icon(Icons.format_color_fill),
        tooltip: 'Fill (tap shapes to fill)',
      ),
      toolButton(
        tool: EditorTool.select,
        icon: const Icon(Icons.ads_click),
        tooltip: 'Select (${_selectionModeLabel(selectionMode)})',
        onActivePress: () async {
          final picked = await showSelectionModePicker(
            context: context,
            current: selectionMode,
          );
          if (picked != null) {
            viewModel.setSelectionMode(picked);
          }
        },
      ),
      toolButton(
        tool: EditorTool.camera,
        icon: const Icon(Icons.videocam_outlined),
        tooltip: 'Scene Camera',
      ),
    ];

    return AppBar(
      title: SizedBox(
        height: kToolbarHeight,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: actionItems),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => showEditorMenu(context: context),
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
        ),
      ],
    );
  }
}

class _EraserIcon extends StatelessWidget {
  const _EraserIcon();

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final color =
        iconTheme.color ?? Theme.of(context).iconTheme.color ?? Colors.black;
    final size = iconTheme.size ?? 24.0;

    return CustomPaint(size: Size.square(size), painter: _EraserPainter(color));
  }
}

class _EraserPainter extends CustomPainter {
  _EraserPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const double angle = -0.55;

    canvas.save();
    final center = Offset(size.width * 0.55, size.height * 0.55);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final bodyRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 0.7,
      height: size.height * 0.35,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(size.width * 0.08)),
      paint,
    );

    paint.color = color.withOpacity(0.65);
    final capRect = Rect.fromCenter(
      center: Offset(-size.width * 0.12, -size.height * 0.06),
      width: size.width * 0.32,
      height: size.height * 0.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, Radius.circular(size.width * 0.05)),
      paint,
    );
    canvas.restore();

    final underlinePaint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.8),
      Offset(size.width * 0.7, size.height * 0.7),
      underlinePaint,
    );
  }

  @override
  bool shouldRepaint(_EraserPainter oldDelegate) => oldDelegate.color != color;
}

String _selectionModeLabel(SelectionMode mode) {
  switch (mode) {
    case SelectionMode.single:
      return 'Single';
    case SelectionMode.lasso:
      return 'Lasso';
    case SelectionMode.multi:
      return 'Multi';
    case SelectionMode.all:
      return 'All';
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom out button
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: 'Zoom out',
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove),
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              tooltip: 'Fit to view',
              onPressed: onResetZoom,
              icon: const Icon(Icons.center_focus_strong),
            ),
          ),
          // Zoom in button
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: 'Zoom in',
              onPressed: onZoomIn,
              icon: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
