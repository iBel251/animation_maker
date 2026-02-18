import 'package:animation_maker/features/canvas/presentation/models/style_edit_scope.dart';
import 'package:flutter/material.dart';

class StyleEditScopeToggle extends StatelessWidget {
  const StyleEditScopeToggle({
    super.key,
    required this.scope,
    required this.onChanged,
  });

  final StyleEditScope scope;
  final ValueChanged<StyleEditScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style Scope',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _scopeOption(
                    context,
                    label: 'Global',
                    icon: Icons.public_outlined,
                    selected: scope == StyleEditScope.global,
                    onTap: () => onChanged(StyleEditScope.global),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _scopeOption(
                    context,
                    label: 'Timeline',
                    icon: Icons.schedule_outlined,
                    selected: scope == StyleEditScope.timeline,
                    onTap: () => onChanged(StyleEditScope.timeline),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withOpacity(0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
