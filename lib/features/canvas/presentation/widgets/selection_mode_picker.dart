import 'package:flutter/material.dart';

import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';

Future<SelectionMode?> showSelectionModePicker({
  required BuildContext context,
  required SelectionMode current,
}) {
  final isCompact = MediaQuery.of(context).size.width < 600;
  if (isCompact) {
    return showModalBottomSheet<SelectionMode>(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: 'Selection mode',
              onClose: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
            _selectionTile(ctx, SelectionMode.single, current, 'Single select'),
            _selectionTile(ctx, SelectionMode.lasso, current, 'Lasso select'),
            _selectionTile(ctx, SelectionMode.multi, current, 'Multi select'),
            _selectionTile(ctx, SelectionMode.all, current, 'Select all'),
          ],
        ),
      ),
    );
  }

  return showDialog<SelectionMode>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: const Text('Selection mode'),
        children: [
          _selectionOption(
            context,
            SelectionMode.single,
            current,
            'Single select',
          ),
          _selectionOption(
            context,
            SelectionMode.lasso,
            current,
            'Lasso select',
          ),
          _selectionOption(
            context,
            SelectionMode.multi,
            current,
            'Multi select',
          ),
          _selectionOption(context, SelectionMode.all, current, 'Select all'),
        ],
      );
    },
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }
}

Widget _selectionOption(
  BuildContext context,
  SelectionMode mode,
  SelectionMode current,
  String label,
) {
  final theme = Theme.of(context);
  final isCurrent = mode == current;
  return SimpleDialogOption(
    onPressed: () => Navigator.of(context).pop(mode),
    child: Row(
      children: [
        Icon(
          isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isCurrent ? theme.colorScheme.primary : theme.iconTheme.color,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
}

Widget _selectionTile(
  BuildContext context,
  SelectionMode mode,
  SelectionMode current,
  String label,
) {
  final theme = Theme.of(context);
  final isCurrent = mode == current;
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(
      isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: isCurrent ? theme.colorScheme.primary : theme.iconTheme.color,
      size: 20,
    ),
    title: Text(label),
    onTap: () => Navigator.of(context).pop(mode),
  );
}
