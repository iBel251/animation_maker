import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_app_bar.dart';
import 'canvas_area.dart';
import 'properties_panel.dart';
import 'timeline_panel.dart';
import 'editor_view_model.dart';
import 'tool_settings_panel.dart';
import 'bottom_action_bar.dart';
import 'selection_action_bar.dart';
import 'group_selection_action_bar.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

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
                      editorViewModelProvider
                          .select((state) => state.isPropertiesOpen),
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
                const Expanded(
                  child: CanvasArea(),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final isOpen = ref.watch(
                      editorViewModelProvider
                          .select((state) => state.isToolPanelOpen),
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
                  editorViewModelProvider
                      .select((state) => state.isPropertiesOpen),
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
                    color: Colors.grey.shade200,
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
                  editorViewModelProvider
                      .select((state) => state.isToolPanelOpen),
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
                    color: Colors.grey.shade200,
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
          SafeArea(
            top: false,
            child: TimelinePanel(),
          ),
          BottomActionBar(),
        ],
      ),
    );
  }
}
