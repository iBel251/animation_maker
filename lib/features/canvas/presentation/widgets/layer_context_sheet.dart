import 'package:animation_maker/features/canvas/domain/entities/canvas_layer.dart';
import 'package:flutter/material.dart';

/// Shows a context menu for layer operations.
void showLayerContextMenu(
  BuildContext context, {
  required CanvasLayer layer,
  required int layerIndex,
  required int totalLayers,
  required void Function(String layerId, String newName) onRename,
  required void Function(String layerId) onDuplicate,
  required void Function(String layerId) onDelete,
  required void Function(String layerId) onMergeDown,
  required void Function(String layerId, double opacity) onSetOpacity,
  required void Function(String layerId, BlendMode blendMode) onSetBlendMode,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _LayerContextSheet(
      layer: layer,
      layerIndex: layerIndex,
      totalLayers: totalLayers,
      onRename: onRename,
      onDuplicate: onDuplicate,
      onDelete: onDelete,
      onMergeDown: onMergeDown,
      onSetOpacity: onSetOpacity,
      onSetBlendMode: onSetBlendMode,
    ),
  );
}

class _LayerContextSheet extends StatefulWidget {
  const _LayerContextSheet({
    required this.layer,
    required this.layerIndex,
    required this.totalLayers,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMergeDown,
    required this.onSetOpacity,
    required this.onSetBlendMode,
  });

  final CanvasLayer layer;
  final int layerIndex;
  final int totalLayers;
  final void Function(String, String) onRename;
  final void Function(String) onDuplicate;
  final void Function(String) onDelete;
  final void Function(String) onMergeDown;
  final void Function(String, double) onSetOpacity;
  final void Function(String, BlendMode) onSetBlendMode;

  @override
  State<_LayerContextSheet> createState() => _LayerContextSheetState();
}

class _LayerContextSheetState extends State<_LayerContextSheet> {
  late double _opacity;
  late BlendMode _blendMode;

  @override
  void initState() {
    super.initState();
    _opacity = widget.layer.opacity;
    _blendMode = widget.layer.blendMode;
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = widget.totalLayers > 1;
    final canMergeDown = widget.layerIndex < widget.totalLayers - 1;
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Layer name header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                widget.layer.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),

            // Opacity slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Opacity',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _opacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) {
                        setState(() => _opacity = v);
                        widget.onSetOpacity(widget.layer.id, v);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(_opacity * 100).round()}%',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),

            // Blend mode picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.blur_on, size: 20),
                  const SizedBox(width: 12),
                  Text('Blend Mode', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  DropdownButton<BlendMode>(
                    value: _blendMode,
                    underline: const SizedBox.shrink(),
                    items: _supportedBlendModes.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(
                          _blendModeLabel(mode),
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }).toList(),
                    onChanged: (mode) {
                      if (mode == null) return;
                      setState(() => _blendMode = mode);
                      widget.onSetBlendMode(widget.layer.id, mode);
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Actions
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(context).pop();
                _showLayerRenameDialog(
                  context,
                  widget.layer.id,
                  widget.layer.name,
                  widget.onRename,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onDuplicate(widget.layer.id);
              },
            ),
            if (canMergeDown)
              ListTile(
                leading: const Icon(Icons.merge_type),
                title: const Text('Merge Down'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onMergeDown(widget.layer.id);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onDelete(widget.layer.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

const _supportedBlendModes = [
  BlendMode.srcOver,
  BlendMode.multiply,
  BlendMode.screen,
  BlendMode.overlay,
  BlendMode.darken,
  BlendMode.lighten,
  BlendMode.colorDodge,
  BlendMode.colorBurn,
  BlendMode.hardLight,
  BlendMode.softLight,
  BlendMode.difference,
  BlendMode.exclusion,
];

String _blendModeLabel(BlendMode mode) {
  switch (mode) {
    case BlendMode.srcOver:
      return 'Normal';
    case BlendMode.multiply:
      return 'Multiply';
    case BlendMode.screen:
      return 'Screen';
    case BlendMode.overlay:
      return 'Overlay';
    case BlendMode.darken:
      return 'Darken';
    case BlendMode.lighten:
      return 'Lighten';
    case BlendMode.colorDodge:
      return 'Color Dodge';
    case BlendMode.colorBurn:
      return 'Color Burn';
    case BlendMode.hardLight:
      return 'Hard Light';
    case BlendMode.softLight:
      return 'Soft Light';
    case BlendMode.difference:
      return 'Difference';
    case BlendMode.exclusion:
      return 'Exclusion';
    default:
      return mode.name;
  }
}

void _showLayerRenameDialog(
  BuildContext context,
  String layerId,
  String currentName,
  void Function(String layerId, String newName) onRename,
) {
  final controller = TextEditingController(text: currentName);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename Layer'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Layer Name',
          hintText: 'Enter layer name',
        ),
        onSubmitted: (value) {
          Navigator.of(ctx).pop();
          onRename(layerId, value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onRename(layerId, controller.text);
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}
