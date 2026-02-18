import 'package:animation_maker/features/canvas/domain/entities/object_key_channel.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_layout_constants.dart';
import 'package:flutter/material.dart';

class TimelineObjectChannelKeyMenu extends StatelessWidget {
  const TimelineObjectChannelKeyMenu({
    super.key,
    required this.selectedChannels,
    required this.onChannelsChanged,
  });

  final Set<ObjectKeyChannel> selectedChannels;
  final ValueChanged<Set<ObjectKeyChannel>> onChannelsChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Edit Key Channels',
      icon: const Icon(Icons.tune_rounded),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(
        width: TimelineLayoutConstants.minTouchTarget,
        height: TimelineLayoutConstants.minTouchTarget,
      ),
      style: IconButton.styleFrom(
        foregroundColor: const Color(0xFFE8EEF9),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
      ),
      onPressed: () => _showChannelEditor(context),
    );
  }

  Future<void> _showChannelEditor(BuildContext context) async {
    var currentChannels = Set<ObjectKeyChannel>.from(selectedChannels);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2533),
              titlePadding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              contentPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Key Channels',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFE8EEF9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF9AA6BF),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in _channelOptions)
                      _ChannelSwitchTile(
                        option: option,
                        value: currentChannels.contains(option.channel),
                        onChanged: (enabled) {
                          final nextChannels = Set<ObjectKeyChannel>.from(
                            currentChannels,
                          );
                          if (enabled) {
                            nextChannels.add(option.channel);
                          } else {
                            nextChannels.remove(option.channel);
                          }
                          setDialogState(() {
                            currentChannels = nextChannels;
                          });
                          onChannelsChanged(nextChannels);
                        },
                      ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'All channels off removes the keyframe at this frame.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9AA6BF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChannelSwitchTile extends StatelessWidget {
  const _ChannelSwitchTile({
    required this.option,
    required this.value,
    required this.onChanged,
  });

  final _ObjectKeyChannelOption option;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      dense: true,
      activeColor: const Color(0xFF71A2FF),
      activeTrackColor: const Color(0xFF31578F),
      inactiveThumbColor: const Color(0xFF8A97B3),
      inactiveTrackColor: const Color(0xFF2B3447),
      title: Row(
        children: [
          Icon(option.icon, size: 18, color: option.iconColor),
          const SizedBox(width: 10),
          Text(
            option.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFDDE5F4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _ObjectKeyChannelOption {
  const _ObjectKeyChannelOption({
    required this.channel,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final ObjectKeyChannel channel;
  final String label;
  final IconData icon;
  final Color iconColor;
}

const List<_ObjectKeyChannelOption> _channelOptions = <_ObjectKeyChannelOption>[
  _ObjectKeyChannelOption(
    channel: ObjectKeyChannel.position,
    label: 'Position',
    icon: Icons.open_with_rounded,
    iconColor: Color(0xFF77A7FF),
  ),
  _ObjectKeyChannelOption(
    channel: ObjectKeyChannel.rotation,
    label: 'Rotation',
    icon: Icons.rotate_right_rounded,
    iconColor: Color(0xFF77A7FF),
  ),
  _ObjectKeyChannelOption(
    channel: ObjectKeyChannel.scale,
    label: 'Scale',
    icon: Icons.zoom_out_map_rounded,
    iconColor: Color(0xFF77A7FF),
  ),
  _ObjectKeyChannelOption(
    channel: ObjectKeyChannel.opacity,
    label: 'Opacity',
    icon: Icons.opacity_rounded,
    iconColor: Color(0xFF57C9AE),
  ),
  _ObjectKeyChannelOption(
    channel: ObjectKeyChannel.visibility,
    label: 'Visibility',
    icon: Icons.visibility_rounded,
    iconColor: Color(0xFF57C9AE),
  ),
  _ObjectKeyChannelOption(
    channel: ObjectKeyChannel.strokeWidth,
    label: 'Stroke Width',
    icon: Icons.line_weight_rounded,
    iconColor: Color(0xFFF0B35A),
  ),
  _ObjectKeyChannelOption(
    channel: ObjectKeyChannel.strokeColor,
    label: 'Stroke Color',
    icon: Icons.format_color_text_rounded,
    iconColor: Color(0xFFF0B35A),
  ),
  _ObjectKeyChannelOption(
    channel: ObjectKeyChannel.fillColor,
    label: 'Fill Color',
    icon: Icons.format_color_fill_rounded,
    iconColor: Color(0xFFE58EA4),
  ),
];
