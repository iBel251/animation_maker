import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/core/constants/animation_constants.dart';
import 'package:animation_maker/core/utils/id_generator.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_background.dart';
import 'package:animation_maker/features/canvas/domain/entities/canvas_document.dart';
import 'package:animation_maker/features/canvas/presentation/providers/repository_providers.dart';

class NewProjectDialog extends ConsumerStatefulWidget {
  const NewProjectDialog({super.key});

  @override
  ConsumerState<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends ConsumerState<NewProjectDialog> {
  static const List<_CanvasPreset> _canvasPresets = [
    _CanvasPreset(label: 'YouTube (1080p)', width: 1920, height: 1080),
    _CanvasPreset(label: 'YouTube (720p)', width: 1280, height: 720),
    _CanvasPreset(label: 'Shorts (1080)', width: 1080, height: 1920),
    _CanvasPreset(label: 'Shorts (720)', width: 720, height: 1280),
    _CanvasPreset(label: 'Instagram (16:9)', width: 1920, height: 1080),
    _CanvasPreset(label: 'Instagram (1:1)', width: 1080, height: 1080),
    _CanvasPreset(label: '4:3', width: 1440, height: 1080),
  ];
  static const List<Color> _backgroundOptions = [
    Color(0xFFFFFFFF),
    Color(0xFFFDE68A),
    Color(0xFFFCA5A5),
    Color(0xFF93C5FD),
    Color(0xFF34D399),
    Color(0xFF111827),
  ];

  late final TextEditingController _projectNameController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;

  double _fpsSliderValue = 24;
  int _fps = 24;
  String _presetLabel = 'Custom';
  bool _transparentBackground = false;
  Color _backgroundColor = _backgroundOptions.first;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController(text: 'Untitled Project');
    _widthController = TextEditingController(text: '1920');
    _heightController = TextEditingController(text: '1080');
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateProject() async {
    if (_isSaving) return;
    final document = _buildDocument();
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(canvasRepositoryProvider);
      await repo.saveDocument(document);
      if (!mounted) return;
      Navigator.of(context).pop(document.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create project.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  CanvasDocument _buildDocument() {
    final name = _projectNameController.text.trim();
    final title = name.isEmpty ? 'Untitled Project' : name;
    final width = _parseDimension(
      _widthController.text,
      kDefaultCanvasSize.width,
    );
    final height = _parseDimension(
      _heightController.text,
      kDefaultCanvasSize.height,
    );
    final background = _resolveBackground();
    return CanvasDocument.singleLayer(
      id: IdGenerator.documentId(),
      title: title,
      size: Size(width, height),
      background: background,
      fps: _fps.toDouble(),
      frameCount: kDefaultFrameCount,
    );
  }

  CanvasBackground _resolveBackground() {
    if (_transparentBackground) {
      return const CanvasBackground.transparent();
    }
    return CanvasBackground.solid(_backgroundColor);
  }

  double _parseDimension(String raw, double fallback) {
    final value = double.tryParse(raw.trim());
    if (value == null || value <= 0) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF4F0E8);
    const panel = Color(0xFFFFFFFF);
    const accent = Color(0xFF1D4ED8);
    const muted = Color(0xFF6B7280);
    const border = Color(0xFFE7E5E4);

    InputDecoration inputDecoration(String label, {String? hintText}) {
      return InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
      );
    }

    Widget sectionCard({
      required String title,
      String? subtitle,
      required Widget child,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Georgia',
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: child,
          ),
        ],
      );
    }

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'New Project',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            sectionCard(
              title: 'Project details',
              subtitle: 'Name and defaults for this project.',
              child: TextField(
                controller: _projectNameController,
                decoration: inputDecoration(
                  'Project name',
                  hintText: 'My animation project',
                ),
              ),
            ),
            const SizedBox(height: 18),
            sectionCard(
              title: 'Frame rate',
              subtitle: 'Set how many frames play per second.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_fps fps',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accent,
                      inactiveTrackColor: accent.withOpacity(0.2),
                      thumbColor: accent,
                      overlayColor: accent.withOpacity(0.12),
                    ),
                    child: Slider(
                      min: 1,
                      max: 30,
                      divisions: 29,
                      value: _fpsSliderValue,
                      label: '$_fps fps',
                      onChanged: (value) {
                        setState(() {
                          _fpsSliderValue = value;
                          _fps = value.round();
                        });
                      },
                      onChangeEnd: (value) {
                        final snapped = _snapFps(value);
                        setState(() {
                          _fps = snapped;
                          _fpsSliderValue = snapped.toDouble();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Snaps every 6 frames',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            sectionCard(
              title: 'Canvas size',
              subtitle: 'Pick a preset or enter a custom size.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _presetLabel,
                    decoration: inputDecoration('Preset'),
                    items: [
                      const DropdownMenuItem(
                        value: 'Custom',
                        child: Text('Custom'),
                      ),
                      ..._canvasPresets.map(
                        (preset) => DropdownMenuItem(
                          value: preset.label,
                          child: Text(preset.label),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _presetLabel = value;
                        if (value != 'Custom') {
                          final preset = _canvasPresets.firstWhere(
                            (option) => option.label == value,
                          );
                          _widthController.text = preset.width.toString();
                          _heightController.text = preset.height.toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _widthController,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration('Width', hintText: 'px'),
                          onChanged: (_) {
                            setState(() => _presetLabel = 'Custom');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration('Height', hintText: 'px'),
                          onChanged: (_) {
                            setState(() => _presetLabel = 'Custom');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Aspect ratio',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const Spacer(),
                      Text(
                        _aspectRatioLabel(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            sectionCard(
              title: 'Background',
              subtitle: 'Choose a starting background color.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _transparentBackground,
                    activeColor: accent,
                    onChanged: (value) {
                      setState(() => _transparentBackground = value);
                    },
                    title: const Text(
                      'Transparent background',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Useful for overlays and compositing.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _backgroundOptions.map((color) {
                      return _BackgroundSwatch(
                        color: color,
                        isSelected:
                            !_transparentBackground && _backgroundColor == color,
                        isDisabled: _transparentBackground,
                        onTap: () {
                          setState(() => _backgroundColor = color);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Add image'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: const BorderSide(color: border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.layers_outlined, size: 18),
                        label: const Text('Select BG'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: const BorderSide(color: border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.color_lens_outlined, size: 18),
                        label: const Text('Pick color'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: const BorderSide(color: border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            decoration: const BoxDecoration(
              color: panel,
              border: Border(top: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: const BorderSide(color: border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleCreateProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Create project'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _aspectRatioLabel() {
    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);
    if (width == null || height == null || height == 0) return '--';
    final divisor = _gcd(width, height);
    if (divisor == 0) return '--';
    return '${width ~/ divisor}:${height ~/ divisor}';
  }

  int _gcd(int a, int b) {
    var valueA = a.abs();
    var valueB = b.abs();
    while (valueB != 0) {
      final temp = valueB;
      valueB = valueA % valueB;
      valueA = temp;
    }
    return valueA;
  }

  int _snapFps(double value) {
    const int minFps = 1;
    const int maxFps = 30;
    const int step = 6;
    final index = ((value - minFps) / step).round();
    final snapped = (minFps + index * step).clamp(minFps, maxFps);
    return snapped.toInt();
  }
}

class _BackgroundSwatch extends StatelessWidget {
  const _BackgroundSwatch({
    required this.color,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFE7E5E4);
    final iconColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return InkResponse(
      onTap: isDisabled ? null : onTap,
      radius: 26,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDisabled ? color.withOpacity(0.35) : color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, size: 18, color: iconColor)
            : null,
      ),
    );
  }
}

class _CanvasPreset {
  const _CanvasPreset({
    required this.label,
    required this.width,
    required this.height,
  });

  final String label;
  final int width;
  final int height;
}
