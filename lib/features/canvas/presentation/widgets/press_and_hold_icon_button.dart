import 'dart:async';

import 'package:flutter/material.dart';

class PressAndHoldIconButton extends StatefulWidget {
  const PressAndHoldIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 22,
    this.iconSize = 15,
    this.repeatInterval = const Duration(milliseconds: 90),
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Duration repeatInterval;

  @override
  State<PressAndHoldIconButton> createState() => _PressAndHoldIconButtonState();
}

class _PressAndHoldIconButtonState extends State<PressAndHoldIconButton> {
  Timer? _repeatTimer;
  bool _isRepeating = false;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _startRepeat() {
    _repeatTimer?.cancel();
    _isRepeating = true;
    widget.onPressed();
    _repeatTimer = Timer.periodic(widget.repeatInterval, (_) {
      widget.onPressed();
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _isRepeating = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Listener(
        onPointerUp: (_) => _stopRepeat(),
        onPointerCancel: (_) => _stopRepeat(),
        child: Material(
          color: theme.colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            onTap: () {
              if (_isRepeating) return;
              widget.onPressed();
            },
            onTapCancel: _stopRepeat,
            onLongPress: _startRepeat,
            borderRadius: BorderRadius.circular(5),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
