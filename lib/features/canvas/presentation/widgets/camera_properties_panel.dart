import 'dart:math' as math;

import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/core/widgets/custom_slider.dart';
import 'package:animation_maker/features/canvas/domain/entities/scene_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/canvas_notifier.dart';

/// Right sidebar panel showing scene camera properties.
///
/// Displayed when the camera tool is active. Provides controls for
/// position, output size, zoom, and rotation.
class CameraPropertiesPanel extends ConsumerStatefulWidget {
  const CameraPropertiesPanel({super.key});

  @override
  ConsumerState<CameraPropertiesPanel> createState() =>
      _CameraPropertiesPanelState();
}

class _CameraPropertiesPanelState extends ConsumerState<CameraPropertiesPanel> {
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  // Track last synced values to avoid unnecessary controller updates
  String _lastSignature = '';

  @override
  void dispose() {
    _xCtrl.dispose();
    _yCtrl.dispose();
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(SceneCamera cam) {
    final sig =
        '${cam.position.dx},${cam.position.dy},${cam.size.width},${cam.size.height}';
    if (sig == _lastSignature) return;
    _lastSignature = sig;
    _xCtrl.text = cam.position.dx.round().toString();
    _yCtrl.text = cam.position.dy.round().toString();
    _wCtrl.text = cam.size.width.round().toString();
    _hCtrl.text = cam.size.height.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final sceneCamera = ref.watch(
      editorViewModelProvider.select((s) => s.sceneCamera),
    );
    final vm = ref.read(editorViewModelProvider.notifier);
    final theme = Theme.of(context);

    if (sceneCamera == null) {
      return Container(
        color: AppColors.grey50,
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off,
                  size: 48, color: AppColors.grey400),
              const SizedBox(height: 12),
              Text(
                'No scene camera',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.grey600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  final docSize = ref
                      .read(editorViewModelProvider)
                      .document
                      .size;
                  vm.setSceneCamera(SceneCamera.fromDocument(docSize));
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Camera'),
              ),
            ],
          ),
        ),
      );
    }

    _syncControllers(sceneCamera);

    return Container(
      color: AppColors.grey50,
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Text(
            'Camera',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Position
          Text('Position', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'X',
                  controller: _xCtrl,
                  onSubmitted: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) {
                      vm.setSceneCameraPosition(
                        Offset(parsed, sceneCamera.position.dy),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  label: 'Y',
                  controller: _yCtrl,
                  onSubmitted: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) {
                      vm.setSceneCameraPosition(
                        Offset(sceneCamera.position.dx, parsed),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Output Size
          Text('Output Size', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'W',
                  controller: _wCtrl,
                  onSubmitted: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null && parsed > 0) {
                      vm.setSceneCameraSize(
                        Size(parsed, sceneCamera.size.height),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  label: 'H',
                  controller: _hCtrl,
                  onSubmitted: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null && parsed > 0) {
                      vm.setSceneCameraSize(
                        Size(sceneCamera.size.width, parsed),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Zoom slider
          CustomSlider(
            label: 'Zoom',
            value: sceneCamera.zoom,
            min: 0.1,
            max: 10.0,
            step: 0.1,
            unit: 'x',
            onChanged: vm.setSceneCameraZoom,
          ),
          const SizedBox(height: 12),

          // Rotation slider
          CustomSlider(
            label: 'Rotation',
            value: sceneCamera.rotation * 180 / math.pi,
            min: -180.0,
            max: 180.0,
            step: 1.0,
            unit: '\u00B0',
            onChanged: (degrees) {
              vm.setSceneCameraRotation(degrees * math.pi / 180);
            },
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: vm.resetSceneCamera,
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: vm.fitSceneCameraToArtboard,
                  child: const Text('Fit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final isVisible = ref.watch(
                editorViewModelProvider.select((s) => s.sceneCameraVisible),
              );
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: vm.toggleSceneCameraVisibility,
                  icon: Icon(
                    isVisible ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                  ),
                  label: Text(isVisible ? 'Hide Camera' : 'Show Camera'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: theme.textTheme.bodySmall,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.textTheme.labelSmall,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}
