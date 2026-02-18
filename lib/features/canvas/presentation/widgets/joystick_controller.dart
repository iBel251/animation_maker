import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/domain/entities/transform_handle.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_bounds.dart';
import 'package:animation_maker/features/canvas/domain/usecases/selection_hit_test.dart';
import 'package:animation_maker/features/canvas/presentation/models/brush_settings.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/models/joystick_mode.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/services/joystick_service.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const double _padSize = 128.0;
const double _handleSize = 44.0;
const double _modeButtonSize = 36.0;
const double _dpadButtonSize = 40.0;
const Duration _moveRepeatInterval = Duration(milliseconds: 16);
const double _launcherSize = 42.0;
const double _launcherOverlap = 14.0;
const double _panelCornerRadius = 16.0;
const double _panelInnerPadding = 10.0;
const double _expandedPanelHeight = 194.0;
const double _screenMargin = 16.0;

class JoystickController extends ConsumerStatefulWidget {
  const JoystickController({super.key});

  @override
  ConsumerState<JoystickController> createState() => _JoystickControllerState();
}

class _JoystickControllerState extends ConsumerState<JoystickController> {
  final JoystickService _service = const JoystickService();
  Offset _dragOffset = Offset.zero;
  Offset _panelOffset = Offset.zero;
  bool _isMinimized = false;

  // Track which D-pad direction is currently pressed
  Offset? _activeDpadDirection;
  Timer? _dpadRepeatTimer;

  // Track which scale button is currently pressed
  String? _activeScaleButton;
  Timer? _scaleRepeatTimer;

  // Track which rotation button is currently pressed
  String? _activeRotateButton;
  Timer? _rotateRepeatTimer;
  // Custom rotation step size in degrees (default 10 degrees)
  double _rotationStepDegrees = 10.0;

  void _updateOffset(Offset localPosition, JoystickMode mode) {
    final center = const Offset(_padSize / 2, _padSize / 2);
    final raw = localPosition - center;
    final clamped = _service.clampOffset(raw);

    if (clamped == _dragOffset) return;
    setState(() {
      _dragOffset = clamped;
    });

    final vm = ref.read(editorViewModelProvider.notifier);
    switch (mode) {
      case JoystickMode.move:
        // Not used for move mode - using buttons instead
        break;
      case JoystickMode.scale:
        vm.applyJoystickScale(_service.scaleFactor(clamped));
        break;
      case JoystickMode.rotate:
        vm.applyJoystickRotate(_service.rotationDelta(clamped));
        break;
    }
  }

  void _resetDrag() {
    setState(() {
      _dragOffset = Offset.zero;
      _activeDpadDirection = null;
      _activeScaleButton = null;
    });
    _scaleRepeatTimer?.cancel();
    _scaleRepeatTimer = null;
  }

  void _handleDpadButton(Offset direction) {
    if (_activeDpadDirection == direction) return; // Already active

    final vm = ref.read(editorViewModelProvider.notifier);
    final state = ref.read(editorViewModelProvider);
    final viewportScale = state.viewportScale;
    final isCameraMode =
        state.activeTool == EditorTool.camera && state.sceneCamera != null;

    setState(() {
      _activeDpadDirection = direction;
    });

    if (isCameraMode) {
      // Camera mode: move scene camera
      final delta = _service.moveDeltaDirectional(
        direction * _service.maxRadius,
        viewportScale: viewportScale,
      );
      vm.moveSceneCamera(delta);

      _dpadRepeatTimer?.cancel();
      _dpadRepeatTimer = Timer.periodic(_moveRepeatInterval, (timer) {
        if (_activeDpadDirection == direction) {
          vm.moveSceneCamera(
            _service.moveDeltaDirectional(
              direction * _service.maxRadius,
              viewportScale: viewportScale,
            ),
          );
        } else {
          timer.cancel();
        }
      });
      return;
    }

    vm.startJoystickTransform();

    // Apply initial movement
    vm.applyJoystickMove(
      _service.moveDeltaDirectional(
        direction * _service.maxRadius,
        viewportScale: viewportScale,
      ),
    );

    // Set up timer for continuous movement while held
    _dpadRepeatTimer?.cancel();
    _dpadRepeatTimer = Timer.periodic(_moveRepeatInterval, (timer) {
      if (_activeDpadDirection == direction) {
        vm.applyJoystickMove(
          _service.moveDeltaDirectional(
            direction * _service.maxRadius,
            viewportScale: viewportScale,
          ),
        );
      } else {
        timer.cancel();
      }
    });
  }

  void _handleDpadButtonRelease() {
    _dpadRepeatTimer?.cancel();
    _dpadRepeatTimer = null;

    if (_activeDpadDirection != null) {
      final state = ref.read(editorViewModelProvider);
      final isCameraMode =
          state.activeTool == EditorTool.camera && state.sceneCamera != null;
      if (!isCameraMode) {
        ref.read(editorViewModelProvider.notifier).endJoystickTransform();
      }
      setState(() {
        _activeDpadDirection = null;
      });
    }
  }

  void _handleScaleButton(String buttonType) {
    if (_activeScaleButton == buttonType) return; // Already active

    final vm = ref.read(editorViewModelProvider.notifier);
    final state = ref.read(editorViewModelProvider);
    final isCameraMode =
        state.activeTool == EditorTool.camera && state.sceneCamera != null;

    setState(() {
      _activeScaleButton = buttonType;
    });

    if (isCameraMode) {
      // Camera mode: zoom scene camera
      final isIncrease =
          buttonType == 'right' ||
          buttonType == 'up' ||
          buttonType == 'top-right' ||
          buttonType == 'bottom-right';
      final factor = isIncrease ? 1.05 : 0.95;
      vm.zoomSceneCamera(factor);

      _scaleRepeatTimer?.cancel();
      _scaleRepeatTimer = Timer.periodic(const Duration(milliseconds: 50), (
        timer,
      ) {
        if (_activeScaleButton == buttonType) {
          vm.zoomSceneCamera(factor);
        } else {
          timer.cancel();
        }
      });
      return;
    }

    vm.startJoystickTransform();

    // Apply initial scale
    _applyScaleButton(buttonType, vm);

    // Set up timer for continuous scaling while held
    _scaleRepeatTimer?.cancel();
    _scaleRepeatTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (_activeScaleButton == buttonType) {
        _applyScaleButton(buttonType, vm);
        // Re-snapshot after each apply to accumulate
        vm.startJoystickTransform();
      } else {
        timer.cancel();
      }
    });
  }

  void _applyScaleButton(String buttonType, EditorViewModel vm) {
    final state = ref.read(editorViewModelProvider);
    final selectedShapeId = state.selectedShapeId;
    if (selectedShapeId == null) return;
    if (state.shapes.isEmpty) return;

    final selectedShapeIndex = state.shapes.indexWhere(
      (s) => s.id == selectedShapeId,
    );
    if (selectedShapeIndex == -1) return;
    final selectedShape = state.shapes[selectedShapeIndex];
    final spatialId = selectedShape.spatialObjectId;
    final spatialShapes = spatialId != null
        ? state.shapes
              .where((s) => s.spatialObjectId == spatialId)
              .toList(growable: false)
        : const <Shape>[];
    final spatialBounds = spatialShapes.isNotEmpty
        ? selectionBoundsForShapesWorld(
            spatialShapes,
            brushSmoothness:
                state.brushSettings[state.currentBrush]!.smoothness,
            strokeScaleWithShape: state.strokeScaleWithShape,
          )
        : null;
    final useSpatial = spatialBounds != null;

    // Get handle positions exactly like hitTestHandle and canvas painter do
    final baseBounds = useSpatial ? spatialBounds : selectedShape.localBounds;
    final selectionBounds = useSpatial
        ? spatialBounds
        : selectionBoundsForShape(
            selectedShape,
            brushSmoothness:
                state.brushSettings[state.currentBrush]!.smoothness,
            strokeScaleWithShape: state.strokeScaleWithShape,
          );
    final selectionBase = selectionBounds ?? baseBounds;
    if (selectionBase == null) return;

    // Use same calculation as canvas painter: matrix from baseBounds ?? selectionBase
    final matrix = useSpatial
        ? Matrix4.identity()
        : selectedShape.matrixForRect(baseBounds ?? selectionBase);
    // Use selectionBase for corners (same as painter uses selectionBase)
    final corners = transformedCorners(selectionBase, matrix);
    final center = Offset(
      (corners[0].dx + corners[2].dx) / 2,
      (corners[0].dy + corners[2].dy) / 2,
    );

    // Calculate edge centers (same as hitTestHandle)
    final topCenter = Offset(
      (corners[0].dx + corners[1].dx) / 2,
      (corners[0].dy + corners[1].dy) / 2,
    );
    final rightCenter = Offset(
      (corners[1].dx + corners[2].dx) / 2,
      (corners[1].dy + corners[2].dy) / 2,
    );
    final bottomCenter = Offset(
      (corners[2].dx + corners[3].dx) / 2,
      (corners[2].dy + corners[3].dy) / 2,
    );
    final leftCenter = Offset(
      (corners[3].dx + corners[0].dx) / 2,
      (corners[3].dy + corners[0].dy) / 2,
    );

    // Get handle position and type based on button (matching hitTestHandle)
    Offset handlePos;
    TransformHandle handle;
    switch (buttonType) {
      case 'up':
      case 'top':
        handle = TransformHandle.scaleY;
        handlePos = topCenter;
        break;
      case 'down':
      case 'bottom':
        handle = TransformHandle.scaleY;
        handlePos = bottomCenter;
        break;
      case 'left':
        handle = TransformHandle.scaleX;
        handlePos = leftCenter;
        break;
      case 'right':
        handle = TransformHandle.scaleX;
        handlePos = rightCenter;
        break;
      case 'top-left':
        handle = TransformHandle.scaleUniform;
        handlePos = corners[0];
        break;
      case 'top-right':
        handle = TransformHandle.scaleUniform;
        handlePos = corners[1];
        break;
      case 'bottom-right':
        handle = TransformHandle.scaleUniform;
        handlePos = corners[2];
        break;
      case 'bottom-left':
        handle = TransformHandle.scaleUniform;
        handlePos = corners[3];
        break;
      default:
        return;
    }

    // Calculate startDistance exactly like the drag logic does
    // Use baseBounds ?? selectionBase for origin (matching painter's pivotBase calculation)
    final pivotBase = baseBounds ?? selectionBase!;
    final origin = pivotBase.center;
    final centerOverride = useSpatial
        ? origin
        : _pivotWorldForShape(selectedShape, origin);
    final axis = useSpatial
        ? hitAxisForHandle(handle, 0.0)
        : hitAxisForHandle(handle, selectedShape.rotation);

    double startDistance;
    if (handle == TransformHandle.scaleUniform) {
      startDistance = (handlePos - centerOverride).distance;
    } else if (axis != null) {
      startDistance =
          ((handlePos - centerOverride).dx * axis.dx +
                  (handlePos - centerOverride).dy * axis.dy)
              .abs();
    } else {
      startDistance = (handlePos - centerOverride).distance;
    }

    if (startDistance <= 0.001) return;

    // Determine if this button should increase or decrease scale based on position
    // Right, up, top-right, bottom-right = increase
    // Left, down, top-left, bottom-left = decrease
    final isIncreaseButton =
        buttonType == 'right' ||
        buttonType == 'up' ||
        buttonType == 'top-right' ||
        buttonType == 'bottom-right';

    // Calculate step delta and new handle position (simulate drag)
    final stepDelta = startDistance * _service.scaleStepSize;

    Offset newHandlePos;
    if (handle == TransformHandle.scaleUniform) {
      // For corners: move along direction from center
      final direction = (handlePos - centerOverride);
      final dirNormalized = direction.distance > 0
          ? direction / direction.distance
          : const Offset(1, 0);
      final delta = isIncreaseButton ? stepDelta : -stepDelta;
      newHandlePos = handlePos + dirNormalized * delta;
    } else {
      // For edges: move along axis in the direction away from center (if increase) or toward center (if decrease)
      if (axis == null || axis == Offset.zero) return;
      final normAxis = axis.distance == 0
          ? const Offset(1, 0)
          : axis / axis.distance;

      // Calculate direction from center to handle along the axis
      final rel = handlePos - centerOverride;
      final projAlongAxis = rel.dx * normAxis.dx + rel.dy * normAxis.dy;
      // Determine direction: positive proj means handle is in positive axis direction from center
      // To increase: move away from center in handle's direction (use sign of projAlongAxis)
      // To decrease: move toward center (opposite sign)
      final directionSign = projAlongAxis >= 0 ? 1.0 : -1.0;
      final delta = isIncreaseButton
          ? stepDelta *
                directionSign // Move away from center
          : -stepDelta * directionSign; // Move toward center
      newHandlePos = handlePos + normAxis * delta;
    }

    // Calculate new distance/projection exactly like drag logic
    double newDistance;
    if (handle == TransformHandle.scaleUniform) {
      newDistance = (newHandlePos - centerOverride).distance;
    } else if (axis != null) {
      final normAxis = axis.distance == 0
          ? const Offset(1, 0)
          : axis / axis.distance;
      final rel = newHandlePos - centerOverride;
      newDistance = (rel.dx * normAxis.dx + rel.dy * normAxis.dy).abs();
    } else {
      newDistance = (newHandlePos - centerOverride).distance;
    }

    if (newDistance <= 0.001) return;

    // Calculate factor exactly like drag logic: factor = newDistance / startDistance
    final factor = (newDistance / startDistance).clamp(0.05, 3.0);

    // Apply using the same TransformSession logic
    if (handle == TransformHandle.scaleUniform) {
      vm.applyJoystickScaleWithHandle(handle, factor, null);
    } else {
      if (axis == null || axis == Offset.zero) return;
      final normAxis = axis.distance == 0
          ? const Offset(1, 0)
          : axis / axis.distance;
      vm.applyJoystickScaleWithHandle(handle, factor, normAxis);
    }
  }

  // Helper to calculate pivot world position (same as drag logic)
  Offset _pivotWorldForShape(Shape shape, Offset origin) {
    return shape.translation + origin + shape.transform.pivot;
  }

  void _handleScaleButtonRelease() {
    _scaleRepeatTimer?.cancel();
    _scaleRepeatTimer = null;

    if (_activeScaleButton != null) {
      final state = ref.read(editorViewModelProvider);
      final isCameraMode =
          state.activeTool == EditorTool.camera && state.sceneCamera != null;
      if (!isCameraMode) {
        ref.read(editorViewModelProvider.notifier).endJoystickTransform();
      }
      setState(() {
        _activeScaleButton = null;
      });
    }
  }

  void _toggleMinimized() {
    if (!_isMinimized) {
      _resetTransientInteractionState();
    }
    final next = !_isMinimized;
    setState(() {
      _isMinimized = next;
      _panelOffset = _clampPanelOffset(_panelOffset, minimized: next);
    });
  }

  void _resetTransientInteractionState() {
    _resetDrag();
    _handleDpadButtonRelease();
    _handleScaleButtonRelease();
    _handleRotateButtonRelease();
  }

  void _movePanelBy(Offset delta) {
    if (delta == Offset.zero) return;
    final candidate = _panelOffset + delta;
    final clamped = _clampPanelOffset(candidate, minimized: _isMinimized);
    if (clamped == _panelOffset) return;
    setState(() {
      _panelOffset = clamped;
    });
  }

  Offset _clampPanelOffset(Offset candidate, {required bool minimized}) {
    final screenSize = MediaQuery.of(context).size;
    final controlWidth = minimized
        ? _launcherSize
        : _expandedPanelWidth + (_launcherSize - _launcherOverlap);
    final controlHeight = minimized ? _launcherSize : _expandedPanelHeight;

    final minDx = -(screenSize.width - (_screenMargin * 2) - controlWidth);
    final minDy = -(screenSize.height - (_screenMargin * 2) - controlHeight);

    return Offset(
      candidate.dx.clamp(minDx > 0 ? 0 : minDx, 0.0).toDouble(),
      candidate.dy.clamp(minDy > 0 ? 0 : minDy, 0.0).toDouble(),
    );
  }

  double get _expandedPanelWidth => _padSize + (_panelInnerPadding * 2);

  @override
  void dispose() {
    _dpadRepeatTimer?.cancel();
    _scaleRepeatTimer?.cancel();
    _rotateRepeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorViewModelProvider);
    final vm = ref.read(editorViewModelProvider.notifier);

    final isCameraMode =
        state.activeTool == EditorTool.camera && state.sceneCamera != null;
    if (!state.joystickControllerEnabled ||
        (state.selectedShapeId == null && !isCameraMode)) {
      return const SizedBox.shrink();
    }

    final activeMode = state.joystickMode;
    final theme = Theme.of(context);
    final handleOffset = _dragOffset + const Offset(_padSize / 2, _padSize / 2);

    final launcher = _JoystickLauncher(
      icon: _isMinimized ? Icons.gamepad : Icons.gamepad_outlined,
      onTap: _toggleMinimized,
      onDragUpdate: _movePanelBy,
    );

    return Transform.translate(
      offset: _panelOffset,
      child: _isMinimized
          ? SizedBox(
              width: _launcherSize,
              height: _launcherSize,
              child: launcher,
            )
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  elevation: 6,
                  color: AppColors.grey100.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(_panelCornerRadius),
                  child: Padding(
                    padding: const EdgeInsets.all(_panelInnerPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModeButton(
                              icon: Icons.open_with,
                              tooltip: 'Move',
                              isActive: activeMode == JoystickMode.move,
                              onPressed: () =>
                                  vm.setJoystickMode(JoystickMode.move),
                            ),
                            const SizedBox(width: 6),
                            _ModeButton(
                              icon: Icons.zoom_out_map,
                              tooltip: 'Scale',
                              isActive: activeMode == JoystickMode.scale,
                              onPressed: () =>
                                  vm.setJoystickMode(JoystickMode.scale),
                            ),
                            const SizedBox(width: 6),
                            _ModeButton(
                              icon: Icons.rotate_right,
                              tooltip: 'Rotate',
                              isActive: activeMode == JoystickMode.rotate,
                              onPressed: () =>
                                  vm.setJoystickMode(JoystickMode.rotate),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (activeMode == JoystickMode.move)
                          _buildDpad(theme)
                        else if (activeMode == JoystickMode.scale)
                          _buildScaleButtons(theme)
                        else if (activeMode == JoystickMode.rotate)
                          _buildRotateButtons(theme)
                        else
                          _buildAnalogJoystick(
                            theme,
                            handleOffset,
                            activeMode,
                            vm,
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -_launcherOverlap,
                  right: -_launcherOverlap,
                  child: launcher,
                ),
              ],
            ),
    );
  }

  Widget _buildScaleButtons(ThemeData theme) {
    return SizedBox(
      width: _padSize,
      height: _padSize,
      child: Stack(
        children: [
          // Center circle (decorative)
          Center(
            child: Container(
              width: _handleSize,
              height: _handleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.zoom_out_map,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          // Directional buttons (up, down, left, right)
          // Up button (increase Y scale)
          Positioned(
            top: 0,
            left: _padSize / 2 - _dpadButtonSize / 2,
            child: _ScaleButton(
              icon: Icons.arrow_upward,
              size: _dpadButtonSize,
              isActive: _activeScaleButton == 'up',
              onPressed: () => _handleScaleButton('up'),
              onReleased: _handleScaleButtonRelease,
            ),
          ),
          // Down button (decrease Y scale)
          Positioned(
            bottom: 0,
            left: _padSize / 2 - _dpadButtonSize / 2,
            child: _ScaleButton(
              icon: Icons.arrow_downward,
              size: _dpadButtonSize,
              isActive: _activeScaleButton == 'down',
              onPressed: () => _handleScaleButton('down'),
              onReleased: _handleScaleButtonRelease,
            ),
          ),
          // Left button (decrease X scale)
          Positioned(
            left: 0,
            top: _padSize / 2 - _dpadButtonSize / 2,
            child: _ScaleButton(
              icon: Icons.arrow_back,
              size: _dpadButtonSize,
              isActive: _activeScaleButton == 'left',
              onPressed: () => _handleScaleButton('left'),
              onReleased: _handleScaleButtonRelease,
            ),
          ),
          // Right button (increase X scale)
          Positioned(
            right: 0,
            top: _padSize / 2 - _dpadButtonSize / 2,
            child: _ScaleButton(
              icon: Icons.arrow_forward,
              size: _dpadButtonSize,
              isActive: _activeScaleButton == 'right',
              onPressed: () => _handleScaleButton('right'),
              onReleased: _handleScaleButtonRelease,
            ),
          ),
          // Corner buttons (top-left, top-right, bottom-left, bottom-right)
          // Top-left corner (scale down uniformly)
          Positioned(
            top: 4,
            left: 4,
            child: _ScaleButton(
              icon: Icons.drag_handle,
              size: _dpadButtonSize * 0.75,
              isActive: _activeScaleButton == 'top-left',
              onPressed: () => _handleScaleButton('top-left'),
              onReleased: _handleScaleButtonRelease,
            ),
          ),
          // Top-right corner (scale up uniformly)
          Positioned(
            top: 4,
            right: 4,
            child: _ScaleButton(
              icon: Icons.drag_handle,
              size: _dpadButtonSize * 0.75,
              isActive: _activeScaleButton == 'top-right',
              onPressed: () => _handleScaleButton('top-right'),
              onReleased: _handleScaleButtonRelease,
            ),
          ),
          // Bottom-left corner (scale down uniformly)
          Positioned(
            bottom: 4,
            left: 4,
            child: _ScaleButton(
              icon: Icons.drag_handle,
              size: _dpadButtonSize * 0.75,
              isActive: _activeScaleButton == 'bottom-left',
              onPressed: () => _handleScaleButton('bottom-left'),
              onReleased: _handleScaleButtonRelease,
            ),
          ),
          // Bottom-right corner (scale up uniformly)
          Positioned(
            bottom: 4,
            right: 4,
            child: _ScaleButton(
              icon: Icons.drag_handle,
              size: _dpadButtonSize * 0.75,
              isActive: _activeScaleButton == 'bottom-right',
              onPressed: () => _handleScaleButton('bottom-right'),
              onReleased: _handleScaleButtonRelease,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotateButtons(ThemeData theme) {
    final state = ref.watch(editorViewModelProvider);
    final selectedShapeId = state.selectedShapeId;
    String rotationText = '0°';

    if (selectedShapeId != null && state.shapes.isNotEmpty) {
      final selectedShapeIndex = state.shapes.indexWhere(
        (s) => s.id == selectedShapeId,
      );
      if (selectedShapeIndex != -1) {
        final selectedShape = state.shapes[selectedShapeIndex];
        // Always calculate from shape's actual rotation and wrap for display
        double degrees = selectedShape.rotation * 180 / math.pi;
        // Wrap to -360 to 360 range
        if (degrees > 360 || degrees < -360) {
          degrees = degrees % 360;
        }
        // When reaching exactly -360 or 360, reset to 0
        if (degrees == -360 || degrees == 360) degrees = 0;
        rotationText = '${degrees.round()}°';
      }
    }

    return SizedBox(
      width: _padSize,
      height: _padSize,
      child: Stack(
        children: [
          // Rotation increment control (positioned at top inside the stack)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Inc:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 40,
                      child: TextField(
                        controller:
                            TextEditingController(
                                text: _rotationStepDegrees.round().toString(),
                              )
                              ..selection = TextSelection.collapsed(
                                offset: _rotationStepDegrees
                                    .round()
                                    .toString()
                                    .length,
                              ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.2,
                              ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.2,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onSubmitted: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null && parsed > 0 && parsed <= 90) {
                            setState(() {
                              _rotationStepDegrees = parsed.clamp(0.1, 90.0);
                            });
                          }
                        },
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null && parsed > 0 && parsed <= 90) {
                            setState(() {
                              _rotationStepDegrees = parsed.clamp(0.1, 90.0);
                            });
                          }
                        },
                      ),
                    ),
                    Text(
                      '°',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Center circle with rotation angle
          Center(
            child: Container(
              width: _handleSize,
              height: _handleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  rotationText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Left button (rotate counter-clockwise/decrease)
          Positioned(
            left: 0,
            top: _padSize / 2 - _dpadButtonSize / 2,
            child: _RotateButton(
              icon: Icons.rotate_left,
              size: _dpadButtonSize,
              isActive: _activeRotateButton == 'left',
              onPressed: () => _handleRotateButton('left'),
              onReleased: _handleRotateButtonRelease,
            ),
          ),
          // Right button (rotate clockwise/increase)
          Positioned(
            right: 0,
            top: _padSize / 2 - _dpadButtonSize / 2,
            child: _RotateButton(
              icon: Icons.rotate_right,
              size: _dpadButtonSize,
              isActive: _activeRotateButton == 'right',
              onPressed: () => _handleRotateButton('right'),
              onReleased: _handleRotateButtonRelease,
            ),
          ),
        ],
      ),
    );
  }

  void _handleRotateButton(String direction) {
    if (_activeRotateButton == direction) return; // Already active

    final vm = ref.read(editorViewModelProvider.notifier);
    final state = ref.read(editorViewModelProvider);
    final isCameraMode =
        state.activeTool == EditorTool.camera && state.sceneCamera != null;

    setState(() {
      _activeRotateButton = direction;
    });

    if (isCameraMode) {
      // Camera mode: rotate scene camera
      final stepRadians = _rotationStepDegrees * math.pi / 180;
      final deltaAngle = direction == 'left' ? -stepRadians : stepRadians;
      vm.rotateSceneCamera(deltaAngle);

      _rotateRepeatTimer?.cancel();
      _rotateRepeatTimer = Timer.periodic(const Duration(milliseconds: 50), (
        timer,
      ) {
        if (_activeRotateButton == direction) {
          vm.rotateSceneCamera(deltaAngle);
        } else {
          timer.cancel();
        }
      });
      return;
    }

    vm.startJoystickTransform();

    // Apply initial rotation
    _applyRotation(direction, vm);

    // Set up timer for continuous rotation while held
    _rotateRepeatTimer?.cancel();
    _rotateRepeatTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (_activeRotateButton == direction) {
        _applyRotation(direction, vm);
        // Re-snapshot after each apply to accumulate
        vm.startJoystickTransform();
      } else {
        timer.cancel();
      }
    });
  }

  void _applyRotation(String direction, EditorViewModel vm) {
    // Apply rotation to shape (convert degrees to radians)
    final stepRadians = _rotationStepDegrees * math.pi / 180;
    final deltaAngle = direction == 'left'
        ? -stepRadians // Counter-clockwise
        : stepRadians; // Clockwise
    vm.applyJoystickRotate(deltaAngle);
  }

  void _handleRotateButtonRelease() {
    _rotateRepeatTimer?.cancel();
    _rotateRepeatTimer = null;

    if (_activeRotateButton != null) {
      final state = ref.read(editorViewModelProvider);
      final isCameraMode =
          state.activeTool == EditorTool.camera && state.sceneCamera != null;
      if (!isCameraMode) {
        ref.read(editorViewModelProvider.notifier).endJoystickTransform();
      }
      setState(() {
        _activeRotateButton = null;
      });
    }
  }

  Widget _buildDpad(ThemeData theme) {
    return SizedBox(
      width: _padSize,
      height: _padSize,
      child: Stack(
        children: [
          // Center circle
          Center(
            child: Container(
              width: _handleSize,
              height: _handleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
          ),
          // Up button
          Positioned(
            top: 0,
            left: _padSize / 2 - _dpadButtonSize / 2,
            child: _DpadButton(
              icon: Icons.arrow_upward,
              size: _dpadButtonSize,
              isActive: _activeDpadDirection == const Offset(0, -1),
              onPressed: () => _handleDpadButton(const Offset(0, -1)),
              onReleased: _handleDpadButtonRelease,
            ),
          ),
          // Down button
          Positioned(
            bottom: 0,
            left: _padSize / 2 - _dpadButtonSize / 2,
            child: _DpadButton(
              icon: Icons.arrow_downward,
              size: _dpadButtonSize,
              isActive: _activeDpadDirection == const Offset(0, 1),
              onPressed: () => _handleDpadButton(const Offset(0, 1)),
              onReleased: _handleDpadButtonRelease,
            ),
          ),
          // Left button
          Positioned(
            left: 0,
            top: _padSize / 2 - _dpadButtonSize / 2,
            child: _DpadButton(
              icon: Icons.arrow_back,
              size: _dpadButtonSize,
              isActive: _activeDpadDirection == const Offset(-1, 0),
              onPressed: () => _handleDpadButton(const Offset(-1, 0)),
              onReleased: _handleDpadButtonRelease,
            ),
          ),
          // Right button
          Positioned(
            right: 0,
            top: _padSize / 2 - _dpadButtonSize / 2,
            child: _DpadButton(
              icon: Icons.arrow_forward,
              size: _dpadButtonSize,
              isActive: _activeDpadDirection == const Offset(1, 0),
              onPressed: () => _handleDpadButton(const Offset(1, 0)),
              onReleased: _handleDpadButtonRelease,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalogJoystick(
    ThemeData theme,
    Offset handleOffset,
    JoystickMode mode,
    EditorViewModel vm,
  ) {
    return GestureDetector(
      onPanStart: (details) {
        vm.startJoystickTransform();
        _updateOffset(details.localPosition, mode);
      },
      onPanUpdate: (details) {
        _updateOffset(details.localPosition, mode);
      },
      onPanEnd: (_) {
        vm.endJoystickTransform();
        _resetDrag();
      },
      onPanCancel: () {
        vm.endJoystickTransform();
        _resetDrag();
      },
      child: SizedBox(
        width: _padSize,
        height: _padSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              left: handleOffset.dx - _handleSize / 2,
              top: handleOffset.dy - _handleSize / 2,
              child: Container(
                width: _handleSize,
                height: _handleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// External launcher control for expanding/minimizing and moving the joystick.
/// Kept separate from panel content so future action buttons can be added here.
class _JoystickLauncher extends StatelessWidget {
  const _JoystickLauncher({
    required this.icon,
    required this.onTap,
    required this.onDragUpdate,
  });

  final IconData icon;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Toggle joystick / drag to move',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanUpdate: (details) => onDragUpdate(details.delta),
        child: Container(
          width: _launcherSize,
          height: _launcherSize,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.onPrimary.withOpacity(0.22),
            ),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimary, size: 22),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.6);
    return SizedBox(
      width: _modeButtonSize,
      height: _modeButtonSize,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: onPressed,
        icon: Icon(icon, color: color),
      ),
    );
  }
}

class _DpadButton extends StatefulWidget {
  const _DpadButton({
    required this.icon,
    required this.size,
    required this.isActive,
    required this.onPressed,
    required this.onReleased,
  });

  final IconData icon;
  final double size;
  final bool isActive;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  @override
  State<_DpadButton> createState() => _DpadButtonState();
}

class _DpadButtonState extends State<_DpadButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final iconColor = widget.isActive
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface.withOpacity(0.7);

    return GestureDetector(
      onTapDown: (_) => widget.onPressed(),
      onTapUp: (_) => widget.onReleased(),
      onTapCancel: () => widget.onReleased(),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: Border.all(
            color: widget.isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.2),
            width: widget.isActive ? 2.0 : 1.5,
          ),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(widget.icon, color: iconColor, size: 20),
      ),
    );
  }
}

// Reuse same widget for scale buttons
class _ScaleButton extends _DpadButton {
  const _ScaleButton({
    required super.icon,
    required super.size,
    required super.isActive,
    required super.onPressed,
    required super.onReleased,
  });
}

class _RotateButton extends _DpadButton {
  const _RotateButton({
    required super.icon,
    required super.size,
    required super.isActive,
    required super.onPressed,
    required super.onReleased,
  });
}
