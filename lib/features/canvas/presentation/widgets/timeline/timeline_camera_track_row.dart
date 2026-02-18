import 'dart:math' as math;

import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_layout_constants.dart';
import 'package:flutter/material.dart';

class TimelineCameraTrackRow extends StatelessWidget {
  const TimelineCameraTrackRow({
    super.key,
    required this.frameCount,
    required this.currentFrame,
    required this.keyframeFrames,
    required this.onFrameSelected,
    this.showLeading = true,
  });

  final int frameCount;
  final int currentFrame;
  final Set<int> keyframeFrames;
  final ValueChanged<int> onFrameSelected;
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    final safeFrameCount = frameCount < 1 ? 1 : frameCount;
    return SizedBox(
      height: TimelineLayoutConstants.trackRowHeight,
      child: Row(
        children: [
          if (showLeading)
            Container(
              width: TimelineLayoutConstants.leadingWidth,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_outlined,
                    size: 16,
                    color: AppColors.white70,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Camera',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (var frame = 0; frame < safeFrameCount; frame++)
            _CameraTrackCell(
              frame: frame,
              isCurrent: frame == currentFrame,
              hasKeyframe: keyframeFrames.contains(frame),
              onTap: onFrameSelected,
            ),
        ],
      ),
    );
  }
}

class _CameraTrackCell extends StatelessWidget {
  const _CameraTrackCell({
    required this.frame,
    required this.isCurrent,
    required this.hasKeyframe,
    required this.onTap,
  });

  final int frame;
  final bool isCurrent;
  final bool hasKeyframe;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hasKeyframe
          ? 'Frame ${frame + 1}, keyframed'
          : 'Frame ${frame + 1}',
      child: InkWell(
        onTap: () => onTap(frame),
        child: Container(
          width: TimelineLayoutConstants.frameCellWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent ? Colors.white.withValues(alpha: 0.16) : null,
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              bottom: BorderSide(
                color: isCurrent
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.12),
                width: isCurrent ? 2 : 1,
              ),
            ),
          ),
          child: hasKeyframe
              ? Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.amber.shade300
                          : AppColors.white70,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
