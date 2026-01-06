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

class CanvasScreen extends ConsumerStatefulWidget {
  const CanvasScreen({super.key, this.documentId});

  final String? documentId;

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDocumentIfNeeded();
  }

  @override
  void didUpdateWidget(CanvasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _loadDocumentIfNeeded();
    }
  }

  void _loadDocumentIfNeeded() {
    final id = widget.documentId;
    if (id == null) return;
    Future.microtask(() {
      ref.read(editorViewModelProvider.notifier).loadDocument(id);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(editorViewModelProvider.notifier).saveDocument();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await ref.read(editorViewModelProvider.notifier).saveDocument();
        return true;
      },
      child: Scaffold(
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
      ),
    );
  }
}


