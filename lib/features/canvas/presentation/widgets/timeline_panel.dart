import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';

class TimelinePanel extends ConsumerWidget {
  const TimelinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFrame = ref.watch(
      editorViewModelProvider.select((state) => state.currentFrame),
    );
    final frameCount = ref.watch(
      editorViewModelProvider.select((state) => state.document.frameCount),
    );
    final activeLayer = ref.watch(
      editorViewModelProvider.select((state) => state.activeLayerId),
    );
    return Container(
      height: 80,
      width: double.infinity,
      color: AppColors.grey800,
      alignment: Alignment.center,
      child: Text(
        'Frame ${currentFrame + 1} / $frameCount | Layer $activeLayer',
        style: const TextStyle(
          color: AppColors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}



