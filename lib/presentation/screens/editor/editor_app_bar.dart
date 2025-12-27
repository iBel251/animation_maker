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
    final viewModel = ref.read(editorViewModelProvider.notifier);

    Color? toolColor(EditorTool tool) {
      return activeTool == tool
          ? Theme.of(context).colorScheme.primary
          : null;
    }

    return AppBar(
      title: const Text('2D Animation Editor'),
      actions: [
        IconButton(
          onPressed: () => viewModel.setActiveTool(EditorTool.brush),
          icon: const Icon(Icons.brush),
          tooltip: 'Brush',
          color: toolColor(EditorTool.brush),
        ),
        IconButton(
          onPressed: () => viewModel.setActiveTool(EditorTool.shape),
          icon: const Icon(Icons.crop_square),
          tooltip: 'Shape',
          color: toolColor(EditorTool.shape),
        ),
        IconButton(
          onPressed: () => viewModel.setActiveTool(EditorTool.select),
          icon: const Icon(Icons.ads_click),
          tooltip: 'Select',
          color: toolColor(EditorTool.select),
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
