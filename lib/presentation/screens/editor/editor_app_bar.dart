import 'package:animation_maker/domain/models/shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';
import '../../widgets/adaptive_color_picker.dart';
import '../../widgets/brush_type_picker.dart';
import '../../widgets/shape_type_picker.dart';
import '../../painting/brushes/brush_type.dart';

class EditorAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const EditorAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool =
        ref.watch(editorViewModelProvider.select((state) => state.activeTool));
    final currentColor = ref.watch(
      editorViewModelProvider.select((state) => state.currentColor),
    );
    final isPropertiesOpen = ref.watch(
      editorViewModelProvider.select((state) => state.isPropertiesOpen),
    );
    final shapeDrawKind = ref.watch(
      editorViewModelProvider.select((state) => state.shapeDrawKind),
    );
    final isPanMode = ref.watch(
      editorViewModelProvider.select((state) => state.isPanMode),
    );
    final currentBrush = ref.watch(
      editorViewModelProvider.select((state) => state.currentBrush),
    );
    final viewModel = ref.read(editorViewModelProvider.notifier);

    Widget toolButton({
      required EditorTool tool,
      required IconData icon,
      required String tooltip,
    }) {
      final theme = Theme.of(context);
      final isActive = activeTool == tool;
      final fg = isActive
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withOpacity(0.45);
      final bg = isActive
          ? theme.colorScheme.primary.withOpacity(0.12)
          : Colors.transparent;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => viewModel.setActiveTool(tool),
          icon: Icon(icon),
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
          : Colors.transparent;
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
          : Colors.transparent;
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
            );
            if (picked != null) {
              viewModel.setBrushType(picked);
            }
          },
        ),
      );
    }

    final actionItems = <Widget>[
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
          final picked = await showAdaptiveColorPicker(
            context: context,
            initialColor: currentColor,
          );
          if (picked != null) {
            viewModel.setCurrentColor(picked);
          }
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
        tool: EditorTool.select,
        icon: Icons.ads_click,
        tooltip: 'Select',
      ),
      IconButton(
        onPressed: () {
          debugPrint('Save tapped (placeholder)');
        },
        icon: const Icon(Icons.save),
        tooltip: 'Save',
      ),
    ];

    return AppBar(
      title: const Text('2D Animation Editor'),
      actions: [
        SizedBox(
          height: kToolbarHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: actionItems),
          ),
        ),
      ],
    );
  }
}

Color? _parseHexColor(String input) {
  var value = input.replaceAll('#', '');
  if (value.length == 6) {
    value = 'FF$value';
  }
  if (value.length != 8) return null;
  final intColor = int.tryParse(value, radix: 16);
  if (intColor == null) return null;
  return Color(intColor);
}

String _colorToHex(Color color, {bool includeAlpha = true}) {
  final value = includeAlpha
      ? color.value
      : (0xFF << 24) |
          (color.red << 16) |
          (color.green << 8) |
          color.blue;
  return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}
