import 'package:flutter/material.dart';

import '../painting/brushes/brush_type.dart';

Future<BrushType?> showBrushTypePicker({
  required BuildContext context,
  required BrushType current,
  required bool palmRejectionEnabled,
  required VoidCallback onTogglePalmRejection,
  required bool brushVectorMode,
  required VoidCallback onToggleBrushVectorMode,
}) async {
  final isCompact = MediaQuery.of(context).size.width < 600;
  final content = _BrushPickerContent(
    current: current,
    palmRejectionEnabled: palmRejectionEnabled,
    onTogglePalmRejection: onTogglePalmRejection,
    brushVectorMode: brushVectorMode,
    onToggleBrushVectorMode: onToggleBrushVectorMode,
  );

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

class _BrushPickerContent extends StatefulWidget {
  const _BrushPickerContent({
    required this.current,
    required this.palmRejectionEnabled,
    required this.onTogglePalmRejection,
    required this.brushVectorMode,
    required this.onToggleBrushVectorMode,
  });

  final BrushType current;
  final bool palmRejectionEnabled;
  final VoidCallback onTogglePalmRejection;
  final bool brushVectorMode;
  final VoidCallback onToggleBrushVectorMode;

  @override
  State<_BrushPickerContent> createState() => _BrushPickerContentState();
}

class _BrushPickerContentState extends State<_BrushPickerContent> {
  late bool _acceptFinger;
  late bool _vectorMode;

  @override
  void initState() {
    super.initState();
    _acceptFinger = !widget.palmRejectionEnabled;
    _vectorMode = widget.brushVectorMode;
  }

  void _toggleFinger() {
    widget.onTogglePalmRejection();
    setState(() {
      _acceptFinger = !_acceptFinger;
    });
  }

  void _toggleVector() {
    widget.onToggleBrushVectorMode();
    setState(() {
      _vectorMode = !_vectorMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finger input',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _acceptFinger
                          ? 'Accepting finger input'
                          : 'Finger rejected (stylus only)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: _acceptFinger, onChanged: (_) => _toggleFinger()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stroke type',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _vectorMode ? 'Vector stroke' : 'Raster stroke',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: _vectorMode, onChanged: (_) => _toggleVector()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final def in kBrushDefinitions)
              _BrushTile(definition: def, selected: def.type == widget.current),
          ],
        ),
      ],
    );
  }
}

class _BrushTile extends StatelessWidget {
  const _BrushTile({required this.definition, required this.selected});

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



