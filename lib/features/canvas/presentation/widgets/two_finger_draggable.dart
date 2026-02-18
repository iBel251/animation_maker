import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that enables drag-and-drop using a two-finger touch gesture.
///
/// This provides an intuitive touch-friendly way to reorder items by
/// placing two fingers on an item and dragging.
///
/// It works with Flutter's standard [DragTarget] widgets by using
/// a callback-based approach for drop handling.
class TwoFingerDraggable<T extends Object> extends StatefulWidget {
  const TwoFingerDraggable({
    super.key,
    required this.data,
    required this.child,
    required this.feedback,
    this.childWhenDragging,
    this.onDragStarted,
    this.onDragEnd,
    this.onDragUpdate,
    this.dragStartThreshold = 8.0,
    this.hapticFeedback = true,
  });

  /// The data that will be passed when this draggable is dropped.
  final T data;

  /// The widget to display when not dragging.
  final Widget child;

  /// The widget to show under the pointer when dragging.
  final Widget feedback;

  /// The widget to show in place of [child] when dragging.
  final Widget? childWhenDragging;

  /// Called when dragging starts.
  final VoidCallback? onDragStarted;

  /// Called when dragging ends with the final position.
  final void Function(Offset globalPosition)? onDragEnd;

  /// Called when drag position updates.
  final void Function(Offset globalPosition)? onDragUpdate;

  /// The minimum distance fingers must move together before drag starts.
  final double dragStartThreshold;

  /// Whether to provide haptic feedback when drag starts.
  final bool hapticFeedback;

  @override
  State<TwoFingerDraggable<T>> createState() => _TwoFingerDraggableState<T>();
}

class _TwoFingerDraggableState<T extends Object>
    extends State<TwoFingerDraggable<T>> {
  final Map<int, Offset> _initialPositions = {};
  final Map<int, Offset> _currentPositions = {};
  bool _isDragging = false;
  Offset _dragPosition = Offset.zero;
  OverlayEntry? _dragAvatar;

  @override
  void dispose() {
    _cleanupDrag();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isDragging) return;
    _initialPositions[event.pointer] = event.localPosition;
    _currentPositions[event.pointer] = event.localPosition;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_currentPositions.containsKey(event.pointer)) return;

    _currentPositions[event.pointer] = event.localPosition;

    if (_isDragging) {
      _updateDrag(event.position);
    } else if (_currentPositions.length >= 2) {
      _checkDragStart(event.position);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _initialPositions.remove(event.pointer);
    _currentPositions.remove(event.pointer);

    if (_isDragging && _currentPositions.isEmpty) {
      _endDrag(event.position);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _initialPositions.remove(event.pointer);
    _currentPositions.remove(event.pointer);

    if (_isDragging && _currentPositions.isEmpty) {
      _cancelDrag();
    }
  }

  void _checkDragStart(Offset globalPosition) {
    if (_initialPositions.length < 2 || _currentPositions.length < 2) return;

    double totalMovement = 0;

    for (final pointerId in _currentPositions.keys) {
      final initial = _initialPositions[pointerId];
      final current = _currentPositions[pointerId];
      if (initial != null && current != null) {
        final delta = current - initial;
        totalMovement += delta.distance;
      }
    }

    final avgMovement = totalMovement / _currentPositions.length;

    if (avgMovement >= widget.dragStartThreshold) {
      _startDrag(globalPosition);
    }
  }

  void _startDrag(Offset globalPosition) {
    if (_isDragging) return;

    if (widget.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _isDragging = true;
      _dragPosition = globalPosition;
    });

    _createDragAvatar();
    widget.onDragStarted?.call();
  }

  void _createDragAvatar() {
    _dragAvatar = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: _dragPosition.dx - 40,
          top: _dragPosition.dy - 15,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              child: widget.feedback,
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_dragAvatar!);
  }

  void _updateDrag(Offset globalPosition) {
    setState(() {
      _dragPosition = globalPosition;
    });
    _dragAvatar?.markNeedsBuild();
    widget.onDragUpdate?.call(globalPosition);
  }

  void _endDrag(Offset globalPosition) {
    _cleanupDrag();
    widget.onDragEnd?.call(globalPosition);

    setState(() {
      _isDragging = false;
      _initialPositions.clear();
      _currentPositions.clear();
    });
  }

  void _cancelDrag() {
    _cleanupDrag();

    setState(() {
      _isDragging = false;
      _initialPositions.clear();
      _currentPositions.clear();
    });
  }

  void _cleanupDrag() {
    _dragAvatar?.remove();
    _dragAvatar = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: _isDragging
          ? (widget.childWhenDragging ??
              Opacity(opacity: 0.5, child: widget.child))
          : widget.child,
    );
  }
}
