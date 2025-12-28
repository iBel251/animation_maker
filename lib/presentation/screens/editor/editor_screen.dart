import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_app_bar.dart';
import 'canvas_area.dart';
import 'properties_panel.dart';
import 'timeline_panel.dart';
import 'editor_view_model.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const EditorAppBar(),
      body: SafeArea(
        child: Row(
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
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: TimelinePanel(),
      ),
    );
  }
}

