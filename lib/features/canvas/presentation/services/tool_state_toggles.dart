import '../providers/canvas_notifier.dart';

class ToolStateToggles {
  EditorState toggleProperties(EditorState state) {
    final newOpen = !state.isPropertiesOpen;
    return state.copyWith(
      isPropertiesOpen: newOpen,
      isToolPanelOpen: newOpen ? false : state.isToolPanelOpen,
    );
  }

  EditorState toggleToolPanel(EditorState state) {
    final newOpen = !state.isToolPanelOpen;
    return state.copyWith(
      isToolPanelOpen: newOpen,
      isPropertiesOpen: newOpen ? false : state.isPropertiesOpen,
    );
  }

  EditorState togglePanMode(EditorState state) {
    return state.copyWith(isPanMode: !state.isPanMode);
  }

  /// When switching to a direct tool, ensure pan mode is disabled.
  EditorState deactivatePan(EditorState state) {
    return state.isPanMode ? state.copyWith(isPanMode: false) : state;
  }
}


