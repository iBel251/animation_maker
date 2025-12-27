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
            const Expanded(
              child: CanvasArea(),
            ),
            const PropertiesPanel(),
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

