import 'package:flutter/material.dart';

import '../painting/brushes/brush_type.dart';

Future<BrushType?> showBrushTypePicker({
  required BuildContext context,
  required BrushType current,
}) async {
  final isCompact = MediaQuery.of(context).size.width < 600;
  final content = _BrushPickerContent(current: current);

  if (isCompact) {
    return showModalBottomSheet<BrushType>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 16,
          bottom: MediaQuery.of(ctx).viewPadding.bottom + 12,
        ),
        child: content,
      ),
    );
  }

  return showDialog<BrushType>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Brush type'),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _BrushPickerContent extends StatelessWidget {
  const _BrushPickerContent({required this.current});

  final BrushType current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final def in kBrushDefinitions)
          _BrushTile(
            definition: def,
            selected: def.type == current,
          ),
      ],
    );
  }
}

class _BrushTile extends StatelessWidget {
  const _BrushTile({
    required this.definition,
    required this.selected,
  });

  final BrushDefinition definition;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primary.withOpacity(0.12)
        : theme.colorScheme.surfaceVariant.withOpacity(0.4);
    final fg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.7);

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(definition.type),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(definition.icon, color: fg, size: 28),
            const SizedBox(height: 6),
            Text(
              definition.label,
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
