import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';

class SelectionActionBar extends ConsumerWidget {
  const SelectionActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId =
        ref.watch(editorViewModelProvider.select((s) => s.selectedShapeId));
    final activeTool =
        ref.watch(editorViewModelProvider.select((s) => s.activeTool));
    final isVectorMode =
        ref.watch(editorViewModelProvider.select((s) => s.brushVectorMode));
    final groupingEnabled =
        ref.watch(editorViewModelProvider.select((s) => s.groupingEnabled));
    final transformAsOne =
        ref.watch(editorViewModelProvider.select((s) => s.transformGroupAsOne));
    final leftOpen = ref.watch(
      editorViewModelProvider.select((s) => s.isPropertiesOpen),
    );
    final rightOpen = ref.watch(
      editorViewModelProvider.select((s) => s.isToolPanelOpen),
    );
    const double leftWidth = 180;
    const double rightWidth = 220;
    final vm = ref.read(editorViewModelProvider.notifier);
    final hasSelection = selectedId != null;
    final show = hasSelection || (activeTool == EditorTool.brush && isVectorMode);
    final theme = Theme.of(context);
    final horizontalPadding = EdgeInsets.only(
      left: leftOpen ? leftWidth + 8 : 8,
      right: rightOpen ? rightWidth + 8 : 8,
    );

    return AnimatedSlide(
      duration: const Duration(milliseconds: 180),
      offset: show ? Offset.zero : const Offset(0, -0.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: show ? 1 : 0,
        child: IgnorePointer(
          ignoring: !show,
          child: Padding(
            padding: horizontalPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    )
                  ],
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IconButton(
                        icon: groupingEnabled
                            ? Icons.link
                            : Icons.link_off,
                        label: 'Group',
                        tooltip: groupingEnabled
                            ? 'Grouping on'
                            : 'Grouping off',
                        action: _Action.groupToggle,
                      ),
                      if (hasSelection) ...[
                        const SizedBox(width: 6),
                        _IconButton(
                          icon: transformAsOne
                              ? Icons.center_focus_strong
                              : Icons.center_focus_weak,
                          label: 'Unified',
                          tooltip: transformAsOne
                              ? 'Transforms as one'
                              : 'Transforms individually',
                          action: _Action.transformMode,
                        ),
                      ],
                      if (hasSelection) ...[
                        const SizedBox(width: 6),
                        const _IconButton(
                          icon: Icons.content_copy,
                          label: 'Duplicate',
                          tooltip: 'Duplicate',
                          action: _Action.duplicate,
                        ),
                        SizedBox(width: 6),
                        const _IconButton(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          tooltip: 'Delete',
                          action: _Action.delete,
                        ),
                        SizedBox(width: 6),
                        const _IconButton(
                          icon: Icons.flip,
                          label: 'Flip H',
                          tooltip: 'Flip horizontal',
                          action: _Action.flipH,
                        ),
                        SizedBox(width: 6),
                        const _IconButton(
                          icon: Icons.flip_camera_android,
                          label: 'Flip V',
                          tooltip: 'Flip vertical',
                          action: _Action.flipV,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Action { duplicate, delete, flipH, flipV, groupToggle, transformMode }

class _IconButton extends ConsumerWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.action,
  });

  final IconData icon;
  final String tooltip;
  final String label;
  final _Action action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(editorViewModelProvider.notifier);
    final theme = Theme.of(context);

    VoidCallback onPressed;
    switch (action) {
      case _Action.duplicate:
        onPressed = vm.duplicateSelected;
        break;
      case _Action.delete:
        onPressed = vm.deleteSelected;
        break;
      case _Action.flipH:
        onPressed = vm.flipSelectedHorizontal;
        break;
      case _Action.flipV:
        onPressed = vm.flipSelectedVertical;
        break;
      case _Action.groupToggle:
        onPressed = vm.toggleGrouping;
        break;
      case _Action.transformMode:
        onPressed = vm.toggleTransformGroupAsOne;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: tooltip,
          icon: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
