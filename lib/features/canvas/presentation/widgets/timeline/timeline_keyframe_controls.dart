import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_layout_constants.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_object_channel_key_menu.dart';
import 'package:flutter/material.dart';

class TimelineKeyframeControls extends StatelessWidget {
  const TimelineKeyframeControls({
    super.key,
    required this.currentFrame,
    required this.frameCount,
    required this.endFrame,
    required this.fps,
    required this.isPlaying,
    required this.primaryTargetsObject,
    required this.hasKeyframeAtCurrentFrame,
    required this.canGoPreviousKeyframe,
    required this.canGoNextKeyframe,
    required this.canPasteKeyframe,
    required this.onTogglePlayPause,
    required this.autoKeyEnabled,
    required this.onToggleAutoKey,
    required this.onEditFps,
    required this.onEditEndFrame,
    required this.onJumpPreviousKeyframe,
    required this.onAddOrUpdateKeyframe,
    this.selectedObjectKeyChannels = const <ObjectKeyChannel>{},
    this.onSetObjectKeyChannels,
    required this.onDeleteKeyframe,
    required this.onJumpNextKeyframe,
    required this.onCopyKeyframe,
    required this.onPasteKeyframe,
    this.trackLabel,
  });

  final int currentFrame;
  final int frameCount;
  final int endFrame;
  final double fps;
  final bool isPlaying;
  final bool primaryTargetsObject;
  final bool hasKeyframeAtCurrentFrame;
  final bool canGoPreviousKeyframe;
  final bool canGoNextKeyframe;
  final bool canPasteKeyframe;
  final bool autoKeyEnabled;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleAutoKey;
  final VoidCallback onEditFps;
  final VoidCallback onEditEndFrame;
  final VoidCallback? onJumpPreviousKeyframe;
  final VoidCallback onAddOrUpdateKeyframe;
  final Set<ObjectKeyChannel> selectedObjectKeyChannels;
  final ValueChanged<Set<ObjectKeyChannel>>? onSetObjectKeyChannels;
  final VoidCallback? onDeleteKeyframe;
  final VoidCallback? onJumpNextKeyframe;
  final VoidCallback? onCopyKeyframe;
  final VoidCallback? onPasteKeyframe;
  final String? trackLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyframeLabel = hasKeyframeAtCurrentFrame ? 'Update Key' : 'Add Key';
    final addIcon = hasKeyframeAtCurrentFrame
        ? Icons.key_rounded
        : Icons.key_outlined;
    final deleteIcon = Icons.key_off_outlined;
    return SizedBox(
      height: TimelineLayoutConstants.controlBarHeight,
      child: Row(
        children: [
          _ControlIconButton(
            tooltip: isPlaying ? 'Pause playback' : 'Play timeline',
            icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onPressed: onTogglePlayPause,
          ),
          _AutoKeyToggleButton(
            enabled: autoKeyEnabled,
            onPressed: onToggleAutoKey,
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FpsButton(fps: fps, onPressed: onEditFps),
                  _EndFrameButton(
                    endFrame: endFrame,
                    onPressed: onEditEndFrame,
                  ),
                  _ControlIconButton(
                    tooltip: 'Previous keyframe',
                    icon: Icons.skip_previous_rounded,
                    onPressed: canGoPreviousKeyframe
                        ? onJumpPreviousKeyframe
                        : null,
                  ),
                  _ControlIconButton(
                    tooltip: keyframeLabel,
                    icon: addIcon,
                    onPressed: onAddOrUpdateKeyframe,
                  ),
                  if (primaryTargetsObject && onSetObjectKeyChannels != null)
                    TimelineObjectChannelKeyMenu(
                      selectedChannels: selectedObjectKeyChannels,
                      onChannelsChanged: onSetObjectKeyChannels!,
                    ),
                  _ControlIconButton(
                    tooltip: 'Delete keyframe',
                    icon: deleteIcon,
                    onPressed: hasKeyframeAtCurrentFrame
                        ? onDeleteKeyframe
                        : null,
                  ),
                  _ControlIconButton(
                    tooltip: 'Copy keyframe',
                    icon: Icons.content_copy_rounded,
                    onPressed: hasKeyframeAtCurrentFrame
                        ? onCopyKeyframe
                        : null,
                  ),
                  _ControlIconButton(
                    tooltip: 'Paste keyframe',
                    icon: Icons.content_paste_rounded,
                    onPressed: canPasteKeyframe ? onPasteKeyframe : null,
                  ),
                  _ControlIconButton(
                    tooltip: 'Next keyframe',
                    icon: Icons.skip_next_rounded,
                    onPressed: canGoNextKeyframe ? onJumpNextKeyframe : null,
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Frame ${currentFrame + 1}/$frameCount',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trackLabel != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      trackLabel!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(
          width: TimelineLayoutConstants.minTouchTarget,
          height: TimelineLayoutConstants.minTouchTarget,
        ),
        style: IconButton.styleFrom(
          foregroundColor: enabled ? AppColors.white : AppColors.grey600,
        ),
      ),
    );
  }
}

class _FpsButton extends StatelessWidget {
  const _FpsButton({required this.fps, required this.onPressed});

  final double fps;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final rounded = fps == fps.roundToDouble()
        ? fps.toInt().toString()
        : fps.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        label: 'Set FPS',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rounded fps',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndFrameButton extends StatelessWidget {
  const _EndFrameButton({required this.endFrame, required this.onPressed});

  final int endFrame;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        label: 'Set End Frame',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'End $endFrame',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoKeyToggleButton extends StatelessWidget {
  const _AutoKeyToggleButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        label: enabled ? 'Disable Auto-Key' : 'Enable Auto-Key',
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(
              TimelineLayoutConstants.minTouchTarget,
              TimelineLayoutConstants.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            backgroundColor: enabled
                ? Colors.red.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            foregroundColor: enabled ? Colors.red.shade200 : AppColors.white70,
          ),
          child: Text(
            'Auto-Key',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
