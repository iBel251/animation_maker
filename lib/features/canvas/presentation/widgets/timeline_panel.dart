import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animation_maker/core/constants/app_colors.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_camera_track_row.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_frame_ruler.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_keyframe_controls.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_layout_constants.dart';
import 'package:animation_maker/features/canvas/presentation/widgets/timeline/timeline_object_track_row.dart';

class TimelinePanel extends ConsumerStatefulWidget {
  const TimelinePanel({super.key});

  @override
  ConsumerState<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends ConsumerState<TimelinePanel> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  int? _previousFrame;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  /// Scrolls the timeline grid so [frame] is visible, centering it if needed.
  void _scrollToFrame(int frame) {
    if (!_horizontalController.hasClients) return;
    final targetOffset = frame * TimelineLayoutConstants.frameCellWidth;
    final viewportWidth = _horizontalController.position.viewportDimension;
    final currentScroll = _horizontalController.offset;
    final maxScroll = _horizontalController.position.maxScrollExtent;

    // Only scroll if the frame is outside the visible area.
    final cellWidth = TimelineLayoutConstants.frameCellWidth;
    if (targetOffset < currentScroll ||
        targetOffset > currentScroll + viewportWidth - cellWidth) {
      final centeredOffset = (targetOffset - viewportWidth / 2).clamp(
        0.0,
        maxScroll,
      );
      _horizontalController.animateTo(
        centeredOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFrame = ref.watch(
      editorViewModelProvider.select((state) => state.currentFrame),
    );

    // Auto-scroll the timeline when the current frame changes (e.g. via
    // next/previous keyframe buttons or playback).
    if (_previousFrame != currentFrame) {
      _previousFrame = currentFrame;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFrame(currentFrame);
      });
    }
    final fps = ref.watch(
      editorViewModelProvider.select((state) => state.document.fps),
    );
    final frameCount = ref.watch(
      editorViewModelProvider.select((state) => state.document.frameCount),
    );
    final isPlaying = ref.watch(
      editorViewModelProvider.select((state) => state.isTimelinePlaying),
    );
    final autoKeyEnabled = ref.watch(
      editorViewModelProvider.select((state) => state.autoKeyEnabled),
    );
    final timeline = ref.watch(
      editorViewModelProvider.select(
        (state) => state.document.sceneCameraTimeline,
      ),
    );
    final objectTimeline = ref.watch(
      editorViewModelProvider.select((state) => state.document.objectTimeline),
    );
    final selectedShapeId = ref.watch(
      editorViewModelProvider.select((state) => state.selectedShapeId),
    );
    final activeTool = ref.watch(
      editorViewModelProvider.select((state) => state.activeTool),
    );
    final shapes = ref.watch(
      editorViewModelProvider.select((state) => state.shapes),
    );
    final vm = ref.read(editorViewModelProvider.notifier);
    final safeFrameCount = frameCount < 1 ? 1 : frameCount;
    final visibleFrameCount = math.max(
      safeFrameCount,
      TimelineLayoutConstants.minVisibleFrames,
    );
    final previousKeyframe = timeline.previousFrame(currentFrame);
    final nextKeyframe = timeline.nextFrame(currentFrame);
    final keyframeFrames = timeline.frames.toSet();
    Shape? selectedShape;
    if (selectedShapeId != null) {
      for (final shape in shapes) {
        if (shape.id == selectedShapeId) {
          selectedShape = shape;
          break;
        }
      }
    }
    final selectedObjectName = selectedShape == null
        ? null
        : ((selectedShape.name == null || selectedShape.name!.trim().isEmpty)
              ? selectedShape.id
              : selectedShape.name!.trim());
    final hasSelectedObjectKey = selectedShapeId != null
        ? objectTimeline.containsFrame(selectedShapeId, currentFrame)
        : false;
    final previousSelectedObjectKey = selectedShapeId == null
        ? null
        : objectTimeline.previousFrame(selectedShapeId, currentFrame);
    final nextSelectedObjectKey = selectedShapeId == null
        ? null
        : objectTimeline.nextFrame(selectedShapeId, currentFrame);
    final primaryTargetsObject =
        selectedShapeId != null && activeTool != EditorTool.camera;
    final primaryHasKeyAtCurrentFrame = primaryTargetsObject
        ? hasSelectedObjectKey
        : timeline.containsFrame(currentFrame);
    final primaryPreviousKeyframe = primaryTargetsObject
        ? previousSelectedObjectKey
        : previousKeyframe;
    final primaryNextKeyframe = primaryTargetsObject
        ? nextSelectedObjectKey
        : nextKeyframe;
    final primaryAddOrUpdateAction = primaryTargetsObject
        ? vm.addOrUpdateSelectedObjectKeyframeAtCurrentFrame
        : vm.addOrUpdateSceneCameraKeyframeAtCurrentFrame;
    final primaryDeleteAction = !primaryHasKeyAtCurrentFrame
        ? null
        : (primaryTargetsObject
              ? vm.deleteSelectedObjectKeyframeAtCurrentFrame
              : vm.deleteSceneCameraKeyframeAtCurrentFrame);
    final objectTrackData = vm.objectTimelineTrackViewData;
    final selectedObjectKeyChannels =
        vm.selectedObjectKeyChannelsAtCurrentFrame;

    final isCompact = MediaQuery.of(context).size.width < 700;
    final panelHeight = isCompact
        ? TimelineLayoutConstants.panelHeightCompact
        : TimelineLayoutConstants.panelHeightRegular;
    final frameTrackWidth =
        visibleFrameCount * TimelineLayoutConstants.frameCellWidth;

    return Container(
      height: panelHeight,
      width: double.infinity,
      color: AppColors.grey800,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TimelineKeyframeControls(
              currentFrame: currentFrame,
              frameCount: safeFrameCount,
              endFrame: safeFrameCount,
              fps: fps,
              isPlaying: isPlaying,
              primaryTargetsObject: primaryTargetsObject,
              hasKeyframeAtCurrentFrame: primaryHasKeyAtCurrentFrame,
              canGoPreviousKeyframe: primaryPreviousKeyframe != null,
              canGoNextKeyframe: primaryNextKeyframe != null,
              trackLabel: primaryTargetsObject
                  ? (selectedObjectName ?? 'Object')
                  : 'Camera',
              onTogglePlayPause: vm.toggleTimelinePlayback,
              autoKeyEnabled: autoKeyEnabled,
              onToggleAutoKey: vm.toggleAutoKeyEnabled,
              onEditFps: () async {
                final value = await _showFpsDialog(context, fps);
                if (value == null) return;
                vm.updateDocumentMetadata(fps: value);
              },
              onEditEndFrame: () async {
                final value = await _showEndFrameDialog(
                  context,
                  safeFrameCount,
                );
                if (value == null) return;
                vm.updateDocumentMetadata(frameCount: value);
              },
              onJumpPreviousKeyframe: primaryPreviousKeyframe == null
                  ? null
                  : () {
                      if (primaryTargetsObject) {
                        vm.jumpToPreviousSelectedObjectKeyframe();
                        return;
                      }
                      vm.jumpToPreviousSceneCameraKeyframe();
                    },
              onAddOrUpdateKeyframe: primaryAddOrUpdateAction,
              selectedObjectKeyChannels: selectedObjectKeyChannels,
              onSetObjectKeyChannels: primaryTargetsObject
                  ? vm.setSelectedObjectKeyframeChannelsAtCurrentFrame
                  : null,
              onDeleteKeyframe: primaryDeleteAction,
              onCopyKeyframe: primaryHasKeyAtCurrentFrame
                  ? () {
                      if (primaryTargetsObject) {
                        vm.copySelectedObjectKeyframeAtCurrentFrame();
                      } else {
                        vm.copySceneCameraKeyframeAtCurrentFrame();
                      }
                    }
                  : null,
              canPasteKeyframe: vm.canPasteKeyframe(
                primaryTargetsObject: primaryTargetsObject,
              ),
              onPasteKeyframe:
                  vm.canPasteKeyframe(
                    primaryTargetsObject: primaryTargetsObject,
                  )
                  ? () {
                      if (primaryTargetsObject) {
                        vm.pasteSelectedObjectKeyframeAtCurrentFrame();
                      } else {
                        vm.pasteSceneCameraKeyframeAtCurrentFrame();
                      }
                    }
                  : null,
              onJumpNextKeyframe: primaryNextKeyframe == null
                  ? null
                  : () {
                      if (primaryTargetsObject) {
                        vm.jumpToNextSelectedObjectKeyframe();
                        return;
                      }
                      vm.jumpToNextSceneCameraKeyframe();
                    },
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final leadingWidth = TimelineLayoutConstants.leadingWidth;
                const floatingRulerHeight = 16.0;
                final trackViewportHeight = constraints.maxHeight
                    .clamp(0.0, double.infinity)
                    .toDouble();
                final viewportTrackWidth = (constraints.maxWidth - leadingWidth)
                    .clamp(0.0, double.infinity);
                final scrollTrackWidth = math.max(
                  viewportTrackWidth,
                  frameTrackWidth,
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: leadingWidth,
                      child: SizedBox(
                        height: trackViewportHeight,
                        child: ClipRect(
                          child: AnimatedBuilder(
                            animation: _verticalController,
                            builder: (context, child) {
                              final yOffset = _verticalController.hasClients
                                  ? _verticalController.offset
                                  : 0.0;
                              return Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: -yOffset,
                                    child: child!,
                                  ),
                                ],
                              );
                            },
                            child: Column(
                              children: [
                                const _PinnedCameraLeading(),
                                for (final track in objectTrackData)
                                  _PinnedObjectLeading(
                                    key: ValueKey(
                                      'timeline_object_leading_${track.shapeId}',
                                    ),
                                    trackName: track.displayName,
                                    isSelected:
                                        selectedShapeId == track.shapeId,
                                    onTap: () {
                                      vm.selectShape(track.shapeId);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: scrollTrackWidth,
                            height: trackViewportHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Scrollbar(
                                    controller: _verticalController,
                                    child: SingleChildScrollView(
                                      controller: _verticalController,
                                      child: Column(
                                        children: [
                                          TimelineCameraTrackRow(
                                            frameCount: visibleFrameCount,
                                            currentFrame: currentFrame,
                                            keyframeFrames: keyframeFrames,
                                            showLeading: false,
                                            onFrameSelected: (frame) {
                                              vm.setCurrentFrame(frame);
                                            },
                                          ),
                                          for (final track in objectTrackData)
                                            TimelineObjectTrackRow(
                                              key: ValueKey(
                                                'timeline_object_row_${track.shapeId}',
                                              ),
                                              frameCount: visibleFrameCount,
                                              currentFrame: currentFrame,
                                              trackName: track.displayName,
                                              keyframeFrames: track.frames
                                                  .toSet(),
                                              isSelected:
                                                  selectedShapeId ==
                                                  track.shapeId,
                                              showLeading: false,
                                              onFrameSelected: (frame) {
                                                vm.selectShape(track.shapeId);
                                                vm.setCurrentFrame(frame);
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.only(bottom: 1),
                                    color: AppColors.grey800.withValues(
                                      alpha: 0.9,
                                    ),
                                    child: TimelineFrameRuler(
                                      frameCount: visibleFrameCount,
                                      currentFrame: currentFrame,
                                      showLeading: false,
                                      height: floatingRulerHeight,
                                      compact: true,
                                      onFrameSelected: (frame) {
                                        vm.setCurrentFrame(frame);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<double?> _showFpsDialog(
    BuildContext context,
    double currentFps,
  ) async {
    final controller = TextEditingController(
      text: currentFps == currentFps.roundToDouble()
          ? currentFps.toInt().toString()
          : currentFps.toStringAsFixed(1),
    );
    return showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set FPS'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Frames per second',
              hintText: '1 - 240',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed < 1 || parsed > 240) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<int?> _showEndFrameDialog(
    BuildContext context,
    int currentFrameCount,
  ) async {
    final controller = TextEditingController(
      text: currentFrameCount.toString(),
    );
    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set End Frame'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'End frame number',
              hintText: '1 - 1,000,000',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed < 1 || parsed > 1000000) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }
}

class _PinnedCameraLeading extends StatelessWidget {
  const _PinnedCameraLeading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimelineLayoutConstants.trackRowHeight,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Icon(
              Icons.videocam_outlined,
              size: 16,
              color: AppColors.white70,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Camera',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedObjectLeading extends StatelessWidget {
  const _PinnedObjectLeading({
    super.key,
    required this.trackName,
    required this.isSelected,
    required this.onTap,
  });

  final String trackName;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimelineLayoutConstants.trackRowHeight,
      child: Semantics(
        button: true,
        label: 'Select object track $trackName',
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.12) : null,
              border: Border(
                bottom: BorderSide(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 16,
                  color: isSelected
                      ? Colors.lightBlue.shade200
                      : AppColors.white70,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trackName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
