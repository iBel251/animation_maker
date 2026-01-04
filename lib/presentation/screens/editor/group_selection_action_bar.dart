import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';
import 'selection_types.dart';

/// Secondary action bar shown when multi-select (group mode) is active.
/// UI-only for now; buttons are placeholders.
class GroupSelectionActionBar extends ConsumerWidget {
  const GroupSelectionActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionMode =
        ref.watch(editorViewModelProvider.select((s) => s.selectionMode));
    final selectedIds =
        ref.watch(editorViewModelProvider.select((s) => s.selectedShapeIds));
    final leftOpen = ref.watch(
      editorViewModelProvider.select((s) => s.isPropertiesOpen),
    );
    final rightOpen = ref.watch(
      editorViewModelProvider.select((s) => s.isToolPanelOpen),
    );

    final show =
        selectionMode != SelectionMode.single && selectedIds.isNotEmpty;
    if (!show) return const SizedBox.shrink();

    const double leftWidth = 180;
    const double rightWidth = 220;
    final horizontalPadding = EdgeInsets.only(
      left: leftOpen ? leftWidth + 8 : 8,
      right: rightOpen ? rightWidth + 8 : 8,
    );
    final theme = Theme.of(context);

    return Padding(
      padding: horizontalPadding,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _GroupButton(
                icon: Icons.merge_type,
                label: 'Merge',
                tooltip: 'Merge (coming soon)',
              ),
              SizedBox(width: 8),
              _GroupButton(
                icon: Icons.group_work_outlined,
                label: 'Group',
                tooltip: 'Group (coming soon)',
              ),
              SizedBox(width: 8),
              _GroupButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                tooltip: 'Delete (coming soon)',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupButton extends StatelessWidget {
  const _GroupButton({
    required this.icon,
    required this.label,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: tooltip,
          onPressed: () {},
          icon: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
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
