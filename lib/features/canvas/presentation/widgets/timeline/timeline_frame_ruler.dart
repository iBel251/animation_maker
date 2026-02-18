import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_layout_constants.dart';
import 'package:flutter/material.dart';

class TimelineFrameRuler extends StatelessWidget {
  const TimelineFrameRuler({
    super.key,
    required this.frameCount,
    required this.currentFrame,
    required this.onFrameSelected,
    this.showLeading = true,
    this.height = TimelineLayoutConstants.rulerHeight,
    this.compact = false,
  });

  final int frameCount;
  final int currentFrame;
  final ValueChanged<int> onFrameSelected;
  final bool showLeading;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeFrameCount = frameCount < 1 ? 1 : frameCount;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (showLeading)
            Container(
              width: TimelineLayoutConstants.leadingWidth,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Frames',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 9 : 10,
                ),
              ),
            ),
          for (var frame = 0; frame < safeFrameCount; frame++)
            _RulerCell(
              frame: frame,
              isCurrent: frame == currentFrame,
              onTap: onFrameSelected,
              compact: compact,
            ),
        ],
      ),
    );
  }
}

class _RulerCell extends StatelessWidget {
  const _RulerCell({
    required this.frame,
    required this.isCurrent,
    required this.onTap,
    required this.compact,
  });

  final int frame;
  final bool isCurrent;
  final ValueChanged<int> onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final frameNumber = frame + 1;
    final showLabel = compact
        ? (frameNumber % 6 == 0) || isCurrent
        : frame == 0 || frame % 5 == 0 || isCurrent;
    return Semantics(
      button: true,
      label: 'Frame ${frame + 1}',
      child: InkWell(
        onTap: () => onTap(frame),
        child: Container(
          width: TimelineLayoutConstants.frameCellWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent ? Colors.white.withValues(alpha: 0.12) : null,
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: isCurrent ? 2 : 1,
              ),
            ),
          ),
          child: showLabel
              ? Text(
                  '$frameNumber',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.white70,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    fontSize: compact ? 9 : 10,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
