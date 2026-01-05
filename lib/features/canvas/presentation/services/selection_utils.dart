import 'package:animation_maker/features/canvas/domain/entities/shape.dart';

class SelectionUtils {
  const SelectionUtils();

  List<int> selectedGroupIndices(List<Shape> shapes, String? selectedId) {
    if (selectedId == null) return const [];
    final targetIndex = shapes.indexWhere((s) => s.id == selectedId);
    if (targetIndex == -1) return const [];
    final groupId = shapes[targetIndex].groupId;
    if (groupId == null) return [targetIndex];
    final indices = <int>[];
    for (var i = 0; i < shapes.length; i++) {
      if (shapes[i].groupId == groupId) {
        indices.add(i);
      }
    }
    return indices;
  }

  List<Shape> selectedGroupShapes(List<Shape> shapes, String? selectedId) {
    final indices = selectedGroupIndices(shapes, selectedId);
    if (indices.isEmpty) return const [];
    return indices.map((i) => shapes[i]).toList(growable: false);
  }
}



