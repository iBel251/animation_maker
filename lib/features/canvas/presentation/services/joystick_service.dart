import 'dart:math' as math;
import 'dart:ui';

class JoystickService {
  const JoystickService({
    this.deadZone = 8.0,
    this.maxRadius = 60.0,
    this.moveSensitivity = 0.2,
    this.moveStepSize = 3.0, // Fixed step size for directional movement
    this.scaleSensitivity = 0.6,
    this.rotationSensitivity = math.pi / 2,
    this.rotationStepSize = math.pi / 18, // 10 degrees per step
  });

  final double deadZone;
  final double maxRadius;
  final double moveSensitivity;
  final double moveStepSize; // Fixed step size for directional controls
  final double scaleSensitivity;
  final double scaleStepSize =
      0.05; // Fixed step size for directional scaling (5% increments)
  final double rotationSensitivity;
  final double
  rotationStepSize; // Fixed step size for directional rotation (radians per step)

  Offset clampOffset(Offset raw) {
    final distance = raw.distance;
    if (distance <= deadZone) return Offset.zero;
    if (distance <= maxRadius) return raw;
    final ratio = maxRadius / distance;
    return Offset(raw.dx * ratio, raw.dy * ratio);
  }

  /// Snaps input to one of 8 directions and returns a fixed movement delta
  Offset moveDeltaDirectional(Offset raw, {double viewportScale = 1.0}) {
    final distance = raw.distance;
    if (distance <= deadZone) return Offset.zero;

    // Calculate angle in degrees (0 = right, 90 = down, 180 = left, 270 = up)
    // Normalize to 0-360 range first
    var angle = math.atan2(raw.dy, raw.dx) * 180 / math.pi;
    angle = (angle + 360) % 360;

    // Snap to nearest of 8 directions (45-degree increments)
    // Directions: 0=Right, 45=DownRight, 90=Down, 135=DownLeft, 180=Left, 225=UpLeft, 270=Up, 315=UpRight
    final normalizedAngle = ((angle + 22.5) % 360) / 45;
    final direction = normalizedAngle.floor();

    // Convert direction index to unit vector
    Offset directionVector;
    switch (direction) {
      case 0: // Right (0°)
        directionVector = const Offset(1, 0);
        break;
      case 1: // Down-Right (45°)
        directionVector = const Offset(1, 1) / math.sqrt2;
        break;
      case 2: // Down (90°)
        directionVector = const Offset(0, 1);
        break;
      case 3: // Down-Left (135°)
        directionVector = const Offset(-1, 1) / math.sqrt2;
        break;
      case 4: // Left (180°)
        directionVector = const Offset(-1, 0);
        break;
      case 5: // Up-Left (225°)
        directionVector = const Offset(-1, -1) / math.sqrt2;
        break;
      case 6: // Up (270°)
        directionVector = const Offset(0, -1);
        break;
      case 7: // Up-Right (315°)
        directionVector = const Offset(1, -1) / math.sqrt2;
        break;
      default:
        directionVector = Offset.zero;
    }

    // Apply fixed step size, adjusted for viewport scale
    final scale = viewportScale == 0 ? 1.0 : viewportScale;
    return directionVector * (moveStepSize / scale);
  }

  // Kept for backward compatibility, but move mode should use moveDeltaDirectional
  Offset moveDelta(Offset raw, {double viewportScale = 1.0}) {
    final clamped = clampOffset(raw);
    if (clamped == Offset.zero) return Offset.zero;
    final scale = viewportScale == 0 ? 1.0 : viewportScale;
    final normalized = (clamped.distance / maxRadius).clamp(0.0, 1.0);
    final eased = normalized * normalized;
    return clamped * (moveSensitivity * eased / scale);
  }

  double scaleFactor(Offset raw) {
    final clamped = clampOffset(raw);
    if (clamped == Offset.zero) return 1.0;
    final normalized = (-clamped.dy / maxRadius).clamp(-1.0, 1.0);
    final factor = 1.0 + normalized * scaleSensitivity;
    return factor.clamp(0.1, 10.0);
  }

  /// Returns scale factors for directional scaling (up/down/left/right buttons)
  /// up: scaleY increases, down: scaleY decreases
  /// right: scaleX increases, left: scaleX decreases
  /// Returns (scaleX, scaleY) factor
  (double, double) scaleFactorDirectional(String direction) {
    switch (direction) {
      case 'up':
        return (1.0, 1.0 + scaleStepSize);
      case 'down':
        return (1.0, 1.0 - scaleStepSize);
      case 'right':
        return (1.0 + scaleStepSize, 1.0);
      case 'left':
        return (1.0 - scaleStepSize, 1.0);
      default:
        return (1.0, 1.0);
    }
  }

  /// Returns uniform scale factor for corner buttons
  double scaleFactorUniform(String corner) {
    // All corners scale uniformly (increase or decrease both X and Y)
    // Top-right and bottom-right corners scale up, top-left and bottom-left scale down
    switch (corner) {
      case 'top-right':
      case 'bottom-right':
        return 1.0 + scaleStepSize; // Scale up
      case 'top-left':
      case 'bottom-left':
        return 1.0 - scaleStepSize; // Scale down
      default:
        return 1.0;
    }
  }

  double rotationDelta(Offset raw) {
    final clamped = clampOffset(raw);
    if (clamped == Offset.zero) return 0.0;
    final normalized = (clamped.dx / maxRadius).clamp(-1.0, 1.0);
    return normalized * rotationSensitivity;
  }
}
