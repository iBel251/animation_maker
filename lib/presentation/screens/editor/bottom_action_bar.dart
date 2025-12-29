import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';

class BottomActionBar extends ConsumerWidget {
  const BottomActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch state so canUndo/canRedo update.
    ref.watch(editorViewModelProvider);
    final vm = ref.read(editorViewModelProvider.notifier);
    final canUndo = vm.canUndo;
    final canRedo = vm.canRedo;

    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const _ActionIcon(icon: Icons.audiotrack, label: 'Audio'),
              const SizedBox(width: 8),
              _ActionIcon(
                icon: Icons.undo,
                label: 'Undo',
                onPressed: canUndo ? vm.undo : null,
              ),
              const SizedBox(width: 8),
              _ActionIcon(
                icon: Icons.redo,
                label: 'Redo',
                onPressed: canRedo ? vm.redo : null,
              ),
              const SizedBox(width: 8),
              const _ActionIcon(icon: Icons.copy, label: 'Copy'),
              const SizedBox(width: 8),
              const _ActionIcon(icon: Icons.paste, label: 'Paste'),
              const SizedBox(width: 8),
              const _ActionIcon(icon: Icons.layers, label: 'Layers'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final color = enabled
        ? theme.colorScheme.onSurface.withOpacity(0.85)
        : theme.colorScheme.onSurface.withOpacity(0.35);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color),
          tooltip: label,
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
