import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/press_and_hold_icon_button.dart';

class TransformStepperField extends StatelessWidget {
  const TransformStepperField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.step,
    required this.onStep,
    required this.onCommit,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final double step;
  final void Function(double delta) onStep;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        PressAndHoldIconButton(
          icon: Icons.remove,
          onPressed: () => onStep(-step),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: theme.textTheme.labelSmall,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
              onSubmitted: (_) => onCommit(),
              onTapOutside: (_) {
                onCommit();
                focusNode.unfocus();
              },
            ),
          ),
        ),
        const SizedBox(width: 6),
        PressAndHoldIconButton(icon: Icons.add, onPressed: () => onStep(step)),
      ],
    );
  }
}
