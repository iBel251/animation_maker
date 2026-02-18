import 'package:flutter/material.dart';

class SecondaryActionBar extends StatelessWidget {
  const SecondaryActionBar({
    super.key,
    required this.show,
    required this.leftOpen,
    required this.rightOpen,
    required this.children,
  });

  final bool show;
  final bool leftOpen;
  final bool rightOpen;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const double leftWidth = 180;
    const double rightWidth = 220;
    final horizontalPadding = EdgeInsets.only(
      left: leftOpen ? leftWidth + 8 : 8,
      right: rightOpen ? rightWidth + 8 : 8,
    );
    final theme = Theme.of(context);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 180),
      offset: show ? Offset.zero : const Offset(0, -0.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: show ? 1 : 0,
        child: Padding(
          padding: horizontalPadding,
          child: Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              ignoring: !show,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    )
                  ],
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionBarButton extends StatelessWidget {
  const ActionBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onPressed,
    this.isEnabled = true,
    this.isActive = false,
    this.showDropdownIndicator = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final bool isActive;
  final bool showDropdownIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool enabled = isEnabled && onPressed != null;
    final iconColor = isActive
        ? theme.colorScheme.primary
        : enabled
            ? theme.colorScheme.onSurface
            : theme.disabledColor;
    final textColor = isActive
        ? theme.colorScheme.primary
        : enabled
            ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
            : theme.disabledColor;
    final bgColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tooltip,
            onPressed: enabled ? onPressed : null,
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: iconColor),
                if (showDropdownIndicator) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 14,
                    color: iconColor,
                  ),
                ],
              ],
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
