import 'package:flutter/material.dart';

import '../../domain/models/shape.dart';

class ShapeOption {
  const ShapeOption({
    required this.kind,
    required this.icon,
    required this.label,
  });

  final ShapeKind kind;
  final IconData icon;
  final String label;
}

const List<ShapeOption> kShapeOptions = [
  ShapeOption(
    kind: ShapeKind.rectangle,
    icon: Icons.crop_square,
    label: 'Rectangle',
  ),
  ShapeOption(
    kind: ShapeKind.ellipse,
    icon: Icons.circle_outlined,
    label: 'Ellipse',
  ),
  ShapeOption(
    kind: ShapeKind.line,
    icon: Icons.show_chart,
    label: 'Line',
  ),
  ShapeOption(
    kind: ShapeKind.polygon,
    icon: Icons.change_history,
    label: 'Triangle',
  ),
];

ShapeOption shapeOptionFor(ShapeKind kind) {
  return kShapeOptions.firstWhere((opt) => opt.kind == kind);
}

Future<ShapeKind?> showShapeTypePicker({
  required BuildContext context,
  required ShapeKind current,
}) async {
  final isCompact = MediaQuery.of(context).size.width < 600;
  final content = _ShapePickerContent(current: current);

  if (isCompact) {
    return showModalBottomSheet<ShapeKind>(
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

  return showDialog<ShapeKind>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Shape type'),
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

class _ShapePickerContent extends StatelessWidget {
  const _ShapePickerContent({required this.current});

  final ShapeKind current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final opt in kShapeOptions)
          _ShapeTile(
            option: opt,
            selected: opt.kind == current,
          ),
      ],
    );
  }
}

class _ShapeTile extends StatelessWidget {
  const _ShapeTile({
    required this.option,
    required this.selected,
  });

  final ShapeOption option;
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
      onTap: () => Navigator.of(context).pop(option.kind),
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
            Icon(option.icon, color: fg, size: 28),
            const SizedBox(height: 6),
            Text(
              option.label,
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
