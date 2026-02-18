import 'package:flutter/widgets.dart';

import 'package:animation_maker/features/canvas/domain/entities/camera.dart';

/// Controller for animated camera transitions.
///
/// Provides smooth animations when changing camera position, zoom, or rotation.
/// Uses Flutter's [AnimationController] internally for timing.
class CameraAnimationController {
  CameraAnimationController({
    required TickerProvider vsync,
    Duration defaultDuration = const Duration(milliseconds: 300),
    Curve defaultCurve = Curves.easeOutCubic,
  })  : _vsync = vsync,
        _defaultDuration = defaultDuration,
        _defaultCurve = defaultCurve {
    _animationController = AnimationController(vsync: _vsync);
    _animationController.addListener(_onAnimationTick);
  }

  final TickerProvider _vsync;
  final Duration _defaultDuration;
  final Curve _defaultCurve;

  late final AnimationController _animationController;

  Camera? _startCamera;
  Camera? _targetCamera;
  void Function(Camera)? _onUpdate;

  /// Whether an animation is currently in progress.
  bool get isAnimating => _animationController.isAnimating;

  /// The current animation progress (0.0 to 1.0).
  double get progress => _animationController.value;

  /// Animates the camera from [from] to [to].
  ///
  /// [onUpdate] is called on each animation frame with the interpolated camera.
  /// [duration] overrides the default animation duration.
  /// [curve] overrides the default easing curve.
  void animateTo({
    required Camera from,
    required Camera to,
    required void Function(Camera) onUpdate,
    Duration? duration,
    Curve? curve,
  }) {
    // Stop any existing animation
    _animationController.stop();

    _startCamera = from;
    _targetCamera = to;
    _onUpdate = onUpdate;

    final effectiveDuration = duration ?? _defaultDuration;
    final effectiveCurve = curve ?? _defaultCurve;

    _animationController.duration = effectiveDuration;

    // Create curved animation
    final curvedAnimation = CurvedAnimation(
      parent: _animationController,
      curve: effectiveCurve,
    );

    // Reset to beginning and start
    _animationController.value = 0.0;
    _animationController.forward();

    // Update listener to use curved value
    curvedAnimation.addListener(() {
      _onAnimationTickCurved(curvedAnimation.value);
    });
  }

  /// Stops any ongoing animation immediately.
  void stop() {
    _animationController.stop();
    _startCamera = null;
    _targetCamera = null;
    _onUpdate = null;
  }

  /// Completes any ongoing animation immediately, jumping to the target.
  void complete() {
    if (_targetCamera != null && _onUpdate != null) {
      _onUpdate!(_targetCamera!);
    }
    stop();
  }

  void _onAnimationTick() {
    // This is called for the raw animation value
    // We use _onAnimationTickCurved for curved values
  }

  void _onAnimationTickCurved(double curvedValue) {
    if (_startCamera == null || _targetCamera == null || _onUpdate == null) {
      return;
    }

    final interpolated = Camera.lerp(_startCamera!, _targetCamera!, curvedValue);
    _onUpdate!(interpolated);

    // Check if animation completed
    if (curvedValue >= 1.0) {
      _startCamera = null;
      _targetCamera = null;
      _onUpdate = null;
    }
  }

  /// Disposes the controller and releases resources.
  void dispose() {
    _animationController.dispose();
  }
}

/// Mixin to provide camera animation capabilities to a State.
///
/// Usage:
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with SingleTickerProviderStateMixin, CameraAnimationMixin {
///   @override
///   void initState() {
///     super.initState();
///     initCameraAnimation();
///   }
///
///   @override
///   void dispose() {
///     disposeCameraAnimation();
///     super.dispose();
///   }
///
///   void _animateToFitArtboard() {
///     final targetCamera = _cameraService.fitToArtboard(...);
///     animateCamera(
///       from: currentCamera,
///       to: targetCamera,
///       onUpdate: (camera) => setState(() => _camera = camera),
///     );
///   }
/// }
/// ```
mixin CameraAnimationMixin<T extends StatefulWidget> on TickerProviderStateMixin<T> {
  CameraAnimationController? _cameraAnimationController;

  /// Initializes the camera animation controller.
  /// Call this in [initState].
  void initCameraAnimation({
    Duration defaultDuration = const Duration(milliseconds: 300),
    Curve defaultCurve = Curves.easeOutCubic,
  }) {
    _cameraAnimationController = CameraAnimationController(
      vsync: this,
      defaultDuration: defaultDuration,
      defaultCurve: defaultCurve,
    );
  }

  /// Disposes the camera animation controller.
  /// Call this in [dispose].
  void disposeCameraAnimation() {
    _cameraAnimationController?.dispose();
    _cameraAnimationController = null;
  }

  /// Whether a camera animation is currently in progress.
  bool get isCameraAnimating => _cameraAnimationController?.isAnimating ?? false;

  /// Animates the camera from [from] to [to].
  void animateCamera({
    required Camera from,
    required Camera to,
    required void Function(Camera) onUpdate,
    Duration? duration,
    Curve? curve,
  }) {
    _cameraAnimationController?.animateTo(
      from: from,
      to: to,
      onUpdate: onUpdate,
      duration: duration,
      curve: curve,
    );
  }

  /// Stops any ongoing camera animation.
  void stopCameraAnimation() {
    _cameraAnimationController?.stop();
  }

  /// Completes any ongoing camera animation immediately.
  void completeCameraAnimation() {
    _cameraAnimationController?.complete();
  }
}
