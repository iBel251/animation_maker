import 'dart:ui';

enum TransformHandle { scaleUniform, scaleX, scaleY, rotate, pivot }

class HandleHit {
  HandleHit({
    required this.type,
    required this.center,
    required this.startDistance,
    required this.startAngle,
    this.axis,
  });

  final TransformHandle type;
  final Offset center;
  final double startDistance;
  final double startAngle;
  final Offset? axis;
}


