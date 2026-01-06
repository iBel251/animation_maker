import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<Color?> showAdaptiveColorPicker({
  required BuildContext context,
  required Color initialColor,
  VoidCallback? onEyedropperRequested,
}) async {
  final isCompact = MediaQuery.of(context).size.width < 600;
  final hexCtrl = TextEditingController(
    text: colorToHex(
      initialColor,
      includeHashSign: true,
      enableAlpha: true,
    ),
  );
  Color temp = initialColor;

  try {
    if (isCompact) {
      return await showModalBottomSheet<Color>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: _ColorPickerSheet(
              initialColor: initialColor,
              hexController: hexCtrl,
              onColorChanged: (color) => temp = color,
              onCancel: () => Navigator.of(ctx).pop(),
              onSelect: () => Navigator.of(ctx).pop(temp),
              onEyedropperRequested: onEyedropperRequested,
            ),
          ),
        ),
      );
    }

    return await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick color'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _ColorPickerContent(
              initialColor: initialColor,
              hexController: hexCtrl,
              onColorChanged: (color) => temp = color,
              onEyedropperRequested: onEyedropperRequested,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(temp),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  } finally {
    hexCtrl.dispose();
  }
}

class _ColorPickerSheet extends StatelessWidget {
  const _ColorPickerSheet({
    required this.initialColor,
    required this.hexController,
    required this.onColorChanged,
    required this.onCancel,
    required this.onSelect,
    this.onEyedropperRequested,
  });

  final Color initialColor;
  final TextEditingController hexController;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onCancel;
  final VoidCallback onSelect;
  final VoidCallback? onEyedropperRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(
                  'Pick color',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _ColorPickerContent(
                initialColor: initialColor,
                hexController: hexController,
                onColorChanged: onColorChanged,
                onEyedropperRequested: onEyedropperRequested,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onSelect,
                  child: const Text('Select'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerContent extends StatefulWidget {
  const _ColorPickerContent({
    required this.initialColor,
    required this.hexController,
    required this.onColorChanged,
    this.onEyedropperRequested,
  });

  final Color initialColor;
  final TextEditingController hexController;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback? onEyedropperRequested;

  @override
  State<_ColorPickerContent> createState() => _ColorPickerContentState();
}

class _ColorPickerContentState extends State<_ColorPickerContent> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  void _applyColor(Color color, {required bool updateHex}) {
    if (color.value == _currentColor.value) return;
    setState(() => _currentColor = color);
    widget.onColorChanged(color);
    if (updateHex) {
      widget.hexController.text = colorToHex(
        color,
        includeHashSign: true,
        enableAlpha: true,
      );
    }
  }

  void _reset() => _applyColor(widget.initialColor, updateHex: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final pickerWidth = math.min(maxWidth, 320.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ColorIndicator(
                  HSVColor.fromColor(_currentColor),
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.hexController,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                      FilteringTextInputFormatter.allow(
                        RegExp(kValidHexPattern),
                      ),
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Hex',
                      hintText: '#AARRGGBB',
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Copy hex',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.hexController.text),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
                Tooltip(
                  message: widget.onEyedropperRequested == null
                      ? 'Eyedropper not available yet'
                      : 'Pick from screen',
                  child: OutlinedButton.icon(
                    onPressed: widget.onEyedropperRequested,
                    icon: const Icon(Icons.colorize_outlined, size: 18),
                    label: const Text('Eyedropper'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: pickerWidth,
                child: ColorPicker(
                  pickerColor: _currentColor,
                  onColorChanged: (color) =>
                      _applyColor(color, updateHex: false),
                  colorPickerWidth: pickerWidth,
                  pickerAreaHeightPercent: 0.75,
                  enableAlpha: true,
                  displayThumbColor: true,
                  portraitOnly: true,
                  paletteType: PaletteType.hsvWithHue,
                  labelTypes: const [],
                  hexInputController: widget.hexController,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Swatches',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final swatch in _swatches)
                  _ColorSwatch(
                    color: swatch,
                    selected: swatch.value == _currentColor.value,
                    onTap: () => _applyColor(swatch, updateHex: true),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.2);
    final borderWidth = selected ? 2.0 : 1.0;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
        ),
      ),
    );
  }
}

const List<Color> _swatches = [
  Color(0xFF000000),
  Color(0xFFFFFFFF),
  Color(0xFF9CA3AF),
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFF22C55E),
  Color(0xFF14B8A6),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
  Color(0xFFA855F7),
  Color(0xFFEC4899),
];


