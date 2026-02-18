import '../providers/canvas_notifier.dart';

class ToolStateToggles {
  EditorState toggleLeftPanel(EditorState state, LeftPanelTab tab) {
    final isOpen = state.isLeftPanelOpen;
    final shouldOpen = !isOpen || state.leftPanelTab != tab;
    return state.copyWith(
      isLeftPanelOpen: shouldOpen ? true : false,
      leftPanelTab: tab,
      isToolPanelOpen: shouldOpen ? false : state.isToolPanelOpen,
    );
  }

  EditorState toggleToolPanel(EditorState state) {
    final newOpen = !state.isToolPanelOpen;
    return state.copyWith(
      isToolPanelOpen: newOpen,
      isLeftPanelOpen: newOpen ? false : state.isLeftPanelOpen,
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


