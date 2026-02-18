import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('path shapes prefer geometry bounds over legacy bounds', () {
    final shape = Shape(
      id: 'poly-1',
      kind: ShapeKind.polygon,
      bounds: const Rect.fromLTWH(100, 100, 50, 50),
      points: const [
        Offset(0, 0),
        Offset(40, 0),
        Offset(40, 20),
        Offset(0, 20),
      ],
    );

    expect(shape.localBounds, const Rect.fromLTWH(0, 0, 40, 20));
  });

  test('point path bezier bounds include curve extents', () {
    final shape = Shape(
      id: 'pointpath-1',
      kind: ShapeKind.pointPath,
      isClosed: false,
      points: const [
        Offset(0, 0),
        Offset(100, 0),
      ],
      bezierPoints: const [
        BezierPoint(
          position: Offset(0, 0),
          controlOut: Offset(0, 120),
        ),
        BezierPoint(
          position: Offset(100, 0),
          controlIn: Offset(0, 120),
        ),
      ],
    );

    final bounds = shape.localBounds!;
    expect(bounds.top, 0);
    expect(bounds.bottom, greaterThan(0));
    expect(bounds.right, 100);
  });
}
