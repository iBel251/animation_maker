import 'dart:async';

import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';

/// Controls timeline playback (play/pause and frame stepping by FPS).
class TimelinePlaybackViewModel {
  TimelinePlaybackViewModel({
    required EditorState Function() getState,
    required void Function(EditorState) setState,
    required Future<void> Function(int frame) setCurrentFrame,
  }) : _getState = getState,
       _setState = setState,
       _setCurrentFrame = setCurrentFrame;

  final EditorState Function() _getState;
  final void Function(EditorState) _setState;
  final Future<void> Function(int frame) _setCurrentFrame;

  Timer? _playbackTimer;
  final Stopwatch _playbackClock = Stopwatch();
  bool _frameAdvanceInFlight = false;
  int? _queuedFrame;
  int _playbackStartFrame = 0;
  static const int _maxVisualStepPerTick = 1;

  bool get isPlaying => _getState().isTimelinePlaying;

  void togglePlayback() {
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (isPlaying) return;
    _playbackStartFrame = _normalizedStartFrame(_getState());
    _playbackClock
      ..reset()
      ..start();
    _queuedFrame = null;
    _setState(_getState().copyWith(isTimelinePlaying: true));
    _startTimer();
  }

  void pause() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackClock.stop();
    _queuedFrame = null;
    if (!isPlaying) return;
    _setState(_getState().copyWith(isTimelinePlaying: false));
  }

  void restartIfPlaying() {
    if (!isPlaying) return;
    _playbackTimer?.cancel();
    _playbackStartFrame = _normalizedStartFrame(_getState());
    _playbackClock
      ..reset()
      ..start();
    _startTimer();
  }

  void dispose() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackClock.stop();
  }

  void _startTimer() {
    final state = _getState();
    final fps = _normalizedFps(state.document.fps);
    final frameIntervalMicros = (1000000 / fps)
        .round()
        .clamp(1, 1000000)
        .toInt();
    // Poll faster than frame cadence to keep playback responsive and in-sync.
    final pollIntervalMicros = (frameIntervalMicros ~/ 2)
        .clamp(4000, 16000)
        .toInt();
    _playbackTimer = Timer.periodic(
      Duration(microseconds: pollIntervalMicros),
      (_) => _advanceFrameForElapsedTime(),
    );
  }

  void _advanceFrameForElapsedTime() {
    if (!isPlaying) return;

    final state = _getState();
    final frameCount = state.document.frameCount < 1
        ? 1
        : state.document.frameCount;
    final fps = _normalizedFps(state.document.fps);
    final elapsedMicros = _playbackClock.elapsedMicroseconds;
    final elapsedFrames = ((elapsedMicros * fps) / 1000000).floor();
    final targetFrame = (_playbackStartFrame + elapsedFrames) % frameCount;
    _scheduleAdvance(targetFrame);
  }

  void _scheduleAdvance(int targetFrame) {
    if (!isPlaying) return;
    if (_frameAdvanceInFlight) {
      _queuedFrame = targetFrame;
      return;
    }
    final state = _getState();
    final frameCount = state.document.frameCount < 1
        ? 1
        : state.document.frameCount;
    final currentFrame = _normalizeFrame(state.currentFrame, frameCount);
    final normalizedTarget = _normalizeFrame(targetFrame, frameCount);
    final distance = _forwardDistance(
      from: currentFrame,
      to: normalizedTarget,
      modulo: frameCount,
    );
    if (distance == 0) return;

    final step = distance.clamp(1, _maxVisualStepPerTick).toInt();
    var nextFrame = (currentFrame + step) % frameCount;

    // Preserve visual continuity around camera keyframes by not stepping past
    // the next keyframe when it is within this advancement window.
    final nextKeyframe = state.document.sceneCameraTimeline.nextFrame(
      currentFrame,
    );
    if (nextKeyframe != null) {
      final keyDistance = _forwardDistance(
        from: currentFrame,
        to: _normalizeFrame(nextKeyframe, frameCount),
        modulo: frameCount,
      );
      if (keyDistance > 0 && keyDistance <= step) {
        nextFrame = nextKeyframe;
      }
    }

    if (nextFrame == currentFrame) return;
    unawaited(_advanceFrame(nextFrame));
  }

  Future<void> _advanceFrame(int targetFrame) async {
    if (_frameAdvanceInFlight || !isPlaying) return;
    _frameAdvanceInFlight = true;
    try {
      await _setCurrentFrame(targetFrame);
    } finally {
      _frameAdvanceInFlight = false;
    }
    if (!isPlaying) return;
    final queued = _queuedFrame;
    _queuedFrame = null;
    if (queued == null || queued == _getState().currentFrame) return;
    _scheduleAdvance(queued);
  }

  double _normalizedFps(double fps) {
    if (fps.isNaN || fps.isInfinite || fps <= 0) return 24.0;
    return fps.clamp(1.0, 240.0).toDouble();
  }

  int _normalizedStartFrame(EditorState state) {
    final frameCount = state.document.frameCount < 1
        ? 1
        : state.document.frameCount;
    return state.currentFrame.clamp(0, frameCount - 1).toInt();
  }

  int _normalizeFrame(int frame, int frameCount) {
    if (frameCount <= 1) return 0;
    var normalized = frame % frameCount;
    if (normalized < 0) normalized += frameCount;
    return normalized;
  }

  int _forwardDistance({
    required int from,
    required int to,
    required int modulo,
  }) {
    if (modulo <= 1) return 0;
    var distance = (to - from) % modulo;
    if (distance < 0) distance += modulo;
    return distance;
  }
}
