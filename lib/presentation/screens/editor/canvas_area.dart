import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';

class CanvasArea extends ConsumerWidget {
  const CanvasArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shapeCount =
        ref.watch(editorViewModelProvider.select((state) => state.shapes.length));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Text('Canvas Area (placeholder) — Shapes: $shapeCount'),
    );
  }
}

