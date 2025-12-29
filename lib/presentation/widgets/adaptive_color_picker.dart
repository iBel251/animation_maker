import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<Color?> showAdaptiveColorPicker({
  required BuildContext context,
  required Color initialColor,
}) async {
  final isCompact = MediaQuery.of(context).size.width < 600;
  final hexCtrl = TextEditingController(
    text: _colorToHex(initialColor, includeAlpha: true),
  );
  Color temp = initialColor;

  Future<Color?> showPicker(Widget child) {
    if (isCompact) {
      return showModalBottomSheet<Color>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).viewPadding.bottom +
                16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: child,
        ),
      );
    }
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick color'),
        content: child,
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
  }

  try {
    final pickerContent = StatefulBuilder(
      builder: (ctx, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
              pickerColor: temp,
              onColorChanged: (c) {
                setState(() {
                  temp = c;
                  hexCtrl.text = _colorToHex(c, includeAlpha: true);
                });
              },
              enableAlpha: true,
              displayThumbColor: true,
              pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hexCtrl,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Fa-f0-9#]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Hex (#RRGGBB or #AARRGGBB)',
                isDense: true,
              ),
              onChanged: (v) {
                final parsed = _parseHexColor(v);
                if (parsed != null) {
                  setState(() {
                    temp = parsed;
                  });
                }
              },
              onSubmitted: (v) {
                final parsed = _parseHexColor(v);
                if (parsed != null) {
                  setState(() {
                    temp = parsed;
                    hexCtrl.text = _colorToHex(parsed, includeAlpha: true);
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _colorToHex(temp, includeAlpha: true),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: temp,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (isCompact) {
      return await showModalBottomSheet<Color>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).viewPadding.bottom +
                  16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pickerContent,
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(temp),
                        child: const Text('Select'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick color'),
        content: SingleChildScrollView(child: pickerContent),
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

Color? _parseHexColor(String input) {
  var value = input.replaceAll('#', '');
  if (value.length == 6) {
    value = 'FF$value';
  }
  if (value.length != 8) return null;
  final intColor = int.tryParse(value, radix: 16);
  if (intColor == null) return null;
  return Color(intColor);
}

String _colorToHex(Color color, {bool includeAlpha = true}) {
  final keepAlpha = includeAlpha && color.alpha != 0xFF;
  final value = keepAlpha
      ? color.value
      : (0xFF << 24) |
          (color.red << 16) |
          (color.green << 8) |
          color.blue;
  final hex = value.toRadixString(16).padLeft(8, '0').toUpperCase();
  return keepAlpha ? '#$hex' : '#${hex.substring(2)}';
}
