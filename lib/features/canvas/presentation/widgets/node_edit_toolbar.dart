import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toolbar displayed when in node edit mode.
/// Provides node edit actions and, for freehand strokes in weighted edit mode,
/// an influence radius slider to control drag power.
class NodeEditToolbar extends ConsumerWidget {
  const NodeEditToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorViewModelProvider);
    final nodeState = editorState.nodeEditState;
    final vm = ref.read(editorViewModelProvider.notifier);
    final hasMultipleContours = nodeState.hasMultipleContours;
    final activeContourIndex = nodeState.activeContourIndex;
    final totalContourCount = nodeState.totalContourCount;

    // Check if selected shape is freehand + weighted edit
    final selectedShape = editorState.selectedShape;
    final showInfluenceSlider = nodeState.useWeightedEdit &&
        selectedShape != null &&
        selectedShape.kind == ShapeKind.freehand;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Multi-contour navigation
          if (hasMultipleContours) ...[
            _ContourNavigator(
              activeIndex: activeContourIndex,
              totalCount: totalContourCount,
              onPrevious: vm.previousContour,
              onNext: vm.nextContour,
              onExplode: () {
                final success = vm.explodeSelectedContours();
                if (success) {
                  vm.exitNodeEditMode();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Split into $totalContourCount separate shapes'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            _divider(),
          ],
          // Influence radius slider for freehand weighted edit
          if (showInfluenceSlider) ...[
            _InfluenceSlider(
              value: nodeState.weightedInfluenceRadius,
              totalArcLength: nodeState.totalArcLength,
              onChanged: (value) {
                vm.updateNodeEditState(
                  nodeState.copyWith(weightedInfluenceRadius: value),
                );
              },
            ),
            _divider(),
          ],
          // Action buttons
          _ActionButton(
            icon: Icons.select_all,
            tooltip: 'Select all nodes',
            onPressed: vm.selectAllNodes,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.close,
            tooltip: 'Exit node edit mode',
            onPressed: vm.exitNodeEditMode,
          ),
        ],
      ),
    );
  }

  static Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade300,
    );
  }
}

/// Compact slider for adjusting the weighted drag influence radius.
/// Shows an icon, label with percentage, and a slider.
class _InfluenceSlider extends StatelessWidget {
  const _InfluenceSlider({
    required this.value,
    required this.totalArcLength,
    required this.onChanged,
  });

  final double value;
  final double totalArcLength;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // Slider range: 5% to 100% of total arc length, clamped to reasonable px
    final minRadius = (totalArcLength * 0.05).clamp(20.0, 80.0);
    final maxRadius = (totalArcLength * 1.0).clamp(100.0, 1200.0);
    final clamped = value.clamp(minRadius, maxRadius);
    final percent = totalArcLength > 0
        ? ((clamped / totalArcLength) * 100).round()
        : 0;

    // Label: S / M / L / Full based on percentage
    final String sizeLabel;
    if (percent <= 15) {
      sizeLabel = 'Tight';
    } else if (percent <= 40) {
      sizeLabel = 'Medium';
    } else if (percent <= 70) {
      sizeLabel = 'Wide';
    } else {
      sizeLabel = 'Full';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.radio_button_unchecked, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          sizeLabel,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
        SizedBox(
          width: 100,
          height: 24,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: const Color(0xFF1D4ED8),
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: const Color(0xFF1D4ED8),
            ),
            child: Slider(
              value: clamped,
              min: minRadius,
              max: maxRadius,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 18,
              color: isEnabled ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget to navigate between contours in a multi-contour shape.
class _ContourNavigator extends StatelessWidget {
  const _ContourNavigator({
    required this.activeIndex,
    required this.totalCount,
    required this.onPrevious,
    required this.onNext,
    required this.onExplode,
  });

  final int activeIndex;
  final int totalCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onExplode;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1D4ED8);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Previous button
        Tooltip(
          message: 'Previous part (${activeIndex > 0 ? activeIndex : totalCount} of $totalCount)',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onPrevious,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),

        // Current contour indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Part ${activeIndex + 1}/$totalCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: activeColor,
            ),
          ),
        ),

        // Next button
        Tooltip(
          message: 'Next part (${activeIndex < totalCount - 1 ? activeIndex + 2 : 1} of $totalCount)',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onNext,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 4),

        // Explode/Split button
        Tooltip(
          message: 'Split into $totalCount separate shapes',
          child: Material(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onExplode,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.call_split,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog for adjusting path simplification tolerance.
