import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/core/constants/app_colors.dart';
import '../providers/canvas_notifier.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/canvas_widget.dart';
import '../widgets/editor_app_bar.dart';
import '../widgets/group_selection_action_bar.dart';
import '../widgets/properties_panel.dart';
import '../widgets/selection_action_bar.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/tool_settings_panel.dart';

class CanvasScreen extends ConsumerWidget {
  const CanvasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const EditorAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final isOpen = ref.watch(
                      editorViewModelProvider.select(
                        (state) => state.isPropertiesOpen,
                      ),
                    );
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isOpen ? 180 : 0,
                      child: isOpen
                          ? const PropertiesPanel()
                          : const SizedBox.shrink(),
                    );
                  },
                ),
                const Expanded(child: CanvasWidget()),
                Consumer(
                  builder: (context, ref, _) {
                    final isOpen = ref.watch(
                      editorViewModelProvider.select(
                        (state) => state.isToolPanelOpen,
                      ),
                    );
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isOpen ? 220 : 0,
                      child: isOpen
                          ? const ToolSettingsPanel()
                          : const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
            const SelectionActionBar(),
            const GroupSelectionActionBar(),
            Consumer(
              builder: (context, ref, _) {
                final isOpen = ref.watch(
                  editorViewModelProvider.select(
                    (state) => state.isPropertiesOpen,
                  ),
                );
                final notifier = ref.read(editorViewModelProvider.notifier);
                final double buttonSize = 32;
                final double openWidth = 180;
                return Positioned(
                  top: 12,
                  left: isOpen ? openWidth - (buttonSize / 2) : 0,
                  child: Material(
                    elevation: 2,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(12),
                    ),
                    color: AppColors.grey200,
                    child: SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        onPressed: notifier.togglePropertiesPanel,
                        icon: Icon(
                          isOpen ? Icons.chevron_left : Icons.chevron_right,
                        ),
                        tooltip: isOpen ? 'Hide sidebar' : 'Show sidebar',
                      ),
                    ),
                  ),
                );
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final isOpen = ref.watch(
                  editorViewModelProvider.select(
                    (state) => state.isToolPanelOpen,
                  ),
                );
                final notifier = ref.read(editorViewModelProvider.notifier);
                const double buttonSize = 32;
                const double openWidth = 220;
                return Positioned(
                  top: 12,
                  right: isOpen ? openWidth - (buttonSize / 2) : 0,
                  child: Material(
                    elevation: 2,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    color: AppColors.grey200,
                    child: SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        onPressed: notifier.toggleToolPanel,
                        icon: Icon(
                          isOpen ? Icons.chevron_right : Icons.chevron_left,
                        ),
                        tooltip: isOpen ? 'Hide tool panel' : 'Show tool panel',
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SafeArea(top: false, child: TimelinePanel()),
          BottomActionBar(),
        ],
      ),
    );
  }
}


