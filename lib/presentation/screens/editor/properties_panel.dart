import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_view_model.dart';

class PropertiesPanel extends ConsumerWidget {
  const PropertiesPanel({super.key, this.shapeCount});

  /// Optional override for shape count (primarily for hot reload compatibility).
  final int? shapeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedShapeId = ref.watch(
      editorViewModelProvider.select((state) => state.selectedShapeId),
    );
    final shapes = shapeCount ??
        ref.watch(editorViewModelProvider.select((state) => state.shapes.length));

    return Container(
      width: 250,
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedShapeId == null
                      ? 'No object selected'
                      : 'Selected: $selectedShapeId',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Shapes: $shapes',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

