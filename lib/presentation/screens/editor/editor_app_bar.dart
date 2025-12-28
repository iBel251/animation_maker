import 'package:animation_maker/domain/models/shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';

class EditorAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const EditorAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool =
        ref.watch(editorViewModelProvider.select((state) => state.activeTool));
    final isPropertiesOpen = ref.watch(
      editorViewModelProvider.select((state) => state.isPropertiesOpen),
    );
    final shapeDrawKind = ref.watch(
      editorViewModelProvider.select((state) => state.shapeDrawKind),
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

    Widget shapeDropdownButton() {
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

      return PopupMenuButton<ShapeKind>(
        tooltip: 'Shape type',
        initialValue: shapeDrawKind,
        onOpened: () => viewModel.setActiveTool(EditorTool.shape),
        onSelected: (kind) {
          viewModel.setActiveTool(EditorTool.shape);
          viewModel.setShapeDrawKind(kind);
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: ShapeKind.rectangle,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(
              Icons.crop_square,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
          ),
          PopupMenuItem(
            value: ShapeKind.ellipse,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(
              Icons.circle_outlined,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
          ),
          PopupMenuItem(
            value: ShapeKind.line,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(
              Icons.show_chart,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
          ),
          PopupMenuItem(
            value: ShapeKind.polygon,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(
              Icons.change_history,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
          ),
        ],
        constraints: const BoxConstraints(
          minWidth: 80,
          maxWidth: 120,
        ),
        offset: const Offset(0, 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            icon,
            color: fg,
          ),
        ),
      );
    }

    return AppBar(
      title: const Text('2D Animation Editor'),
      actions: [
        IconButton(
          onPressed: viewModel.togglePropertiesPanel,
          icon: Icon(
            isPropertiesOpen ? Icons.chevron_right : Icons.chevron_left,
          ),
          tooltip: isPropertiesOpen ? 'Hide sidebar' : 'Show sidebar',
        ),
        toolButton(
          tool: EditorTool.brush,
          icon: Icons.brush,
          tooltip: 'Brush',
        ),
        shapeDropdownButton(),
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
      ],
    );
  }
}
