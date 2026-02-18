import 'package:animation_maker/features/canvas/domain/entities/selection_types.dart';
import 'package:animation_maker/features/canvas/domain/entities/shape.dart';
import 'package:animation_maker/features/canvas/presentation/models/brush_settings.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_state.dart';
import 'package:animation_maker/features/canvas/presentation/models/editor_tool.dart';
import 'package:animation_maker/features/canvas/presentation/painting/brushes/brush_type.dart';
import 'package:animation_maker/features/canvas/presentation/services/tool_state_toggles.dart';
import 'package:flutter/material.dart';

/// View model for managing tool settings (brush, eraser, toggles)
class ToolSettingsViewModel {
  ToolSettingsViewModel({
    required ToolStateToggles toolToggles,
  }) : _toolToggles = toolToggles;

  final ToolStateToggles _toolToggles;

  EditorState setBrushType(EditorState state, BrushType brush) {
    return state.copyWith(currentBrush: brush);
  }

  EditorState setBrushThickness(EditorState state, double value) {
    final currentSettings = state.brushSettings[state.currentBrush]!;
    final updatedSettings = currentSettings.copyWith(
      thickness: value.clamp(0.5, 300),
    );
    final newBrushSettings = Map<BrushType, BrushSettings>.from(state.brushSettings);
    newBrushSettings[state.currentBrush] = updatedSettings;
    return state.copyWith(brushSettings: newBrushSettings);
  }

  EditorState setBrushOpacity(EditorState state, double value) {
    final currentSettings = state.brushSettings[state.currentBrush]!;
    final updatedSettings = currentSettings.copyWith(
      opacity: value.clamp(0.05, 1.0),
    );
    final newBrushSettings = Map<BrushType, BrushSettings>.from(state.brushSettings);
    newBrushSettings[state.currentBrush] = updatedSettings;
    return state.copyWith(brushSettings: newBrushSettings);
  }

  EditorState setBrushSmoothness(EditorState state, double value) {
    final currentSettings = state.brushSettings[state.currentBrush]!;
    final updatedSettings = currentSettings.copyWith(
      smoothness: value.clamp(0.0, 1.0),
    );
    final newBrushSettings = Map<BrushType, BrushSettings>.from(state.brushSettings);
    newBrushSettings[state.currentBrush] = updatedSettings;
    return state.copyWith(brushSettings: newBrushSettings);
  }

  EditorState setEraserThickness(EditorState state, double value) {
    final updatedSettings = state.eraserSettings.copyWith(
      thickness: value.clamp(0.5, 300),
    );
    return state.copyWith(eraserSettings: updatedSettings);
  }

  EditorState setEraserOpacity(EditorState state, double value) {
    final updatedSettings = state.eraserSettings.copyWith(
      opacity: value.clamp(0.05, 1.0),
    );
    return state.copyWith(eraserSettings: updatedSettings);
  }

  EditorState setEraserSmoothness(EditorState state, double value) {
    final updatedSettings = state.eraserSettings.copyWith(
      smoothness: value.clamp(0.0, 1.0),
    );
    return state.copyWith(eraserSettings: updatedSettings);
  }

  EditorState togglePalmRejection(EditorState state) {
    return state.copyWith(palmRejectionEnabled: !state.palmRejectionEnabled);
  }

  EditorState toggleGrouping(EditorState state, String? Function() nextGroupId) {
    if (state.groupingEnabled) {
      return state.copyWith(groupingEnabled: false, currentGroupId: null);
    } else {
      return state.copyWith(
        groupingEnabled: true,
        currentGroupId: nextGroupId(),
      );
    }
  }

  EditorState toggleTransformGroupAsOne(EditorState state) {
    return state.copyWith(transformGroupAsOne: !state.transformGroupAsOne);
  }

  EditorState setPivotSnap(EditorState state, {bool? enabled, double? strength}) {
    return state.copyWith(
      pivotSnapEnabled: enabled ?? state.pivotSnapEnabled,
      pivotSnapStrength: strength ?? state.pivotSnapStrength,
    );
  }

  EditorState setPivotFlipWithObject(EditorState state, bool flip) {
    return state.copyWith(pivotFlipWithObject: flip);
  }

  EditorState setStrokeScaleWithShape(EditorState state, bool value) {
    return state.copyWith(strokeScaleWithShape: value);
  }

  EditorState setShapeFillColor(EditorState state, Color? color) {
    return state.copyWith(shapeFillColor: color);
  }

  EditorState setCurrentColor(EditorState state, Color color) {
    return state.copyWith(currentColor: color);
  }

  EditorState setShapeDrawKind(EditorState state, ShapeKind kind) {
    return state.copyWith(shapeDrawKind: kind);
  }

  EditorState togglePropertiesPanel(EditorState state) {
    return _toolToggles.toggleLeftPanel(state, LeftPanelTab.selection);
  }

  EditorState toggleLayersPanel(EditorState state) {
    return _toolToggles.toggleLeftPanel(state, LeftPanelTab.layers);
  }

  EditorState setLeftPanelTab(EditorState state, LeftPanelTab tab) {
    return state.copyWith(isLeftPanelOpen: true, leftPanelTab: tab);
  }

  EditorState toggleToolPanel(EditorState state) {
    return _toolToggles.toggleToolPanel(state);
  }

  EditorState togglePanMode(EditorState state) {
    return _toolToggles.togglePanMode(state);
  }

  EditorState setPanMode(EditorState state, bool enabled) {
    if (state.isPanMode == enabled) return state;
    return state.copyWith(isPanMode: enabled);
  }

  EditorState setActiveTool(EditorState state, EditorTool tool) {
    final clearSelection = tool != EditorTool.select;
    final newSelectionMode =
        (tool != EditorTool.select) ? SelectionMode.single : state.selectionMode;
    return _toolToggles.deactivatePan(state).copyWith(
      activeTool: tool,
      selectionMode: newSelectionMode,
      selectedShapeId: clearSelection ? null : state.selectedShapeId,
      clearSelection: clearSelection,
      groupingEnabled: tool == EditorTool.brush || tool == EditorTool.eraser
          ? state.groupingEnabled
          : false,
      currentGroupId: tool == EditorTool.brush || tool == EditorTool.eraser
          ? state.currentGroupId
          : null,
    );
  }
}
