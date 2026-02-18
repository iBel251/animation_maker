I have refactored the secondary app bar as you requested.

Here is a summary of the changes:
1.  I created a new universal `SecondaryActionBar` widget located at `lib/features/canvas/presentation/widgets/secondary_action_bar.dart`. This file also contains a reusable `ActionBarButton` widget.
2.  I updated the `CanvasScreen` at `lib/features/canvas/presentation/screens/canvas_screen.dart` to use this new universal action bar. All the logic for deciding which buttons to display is now centralized within the `_SecondaryActionButtons` widget in that file.

This new implementation makes it much easier to add or change context-specific actions in the future without creating new files.

The following files are now obsolete and can be safely deleted:
- `lib/features/canvas/presentation/widgets/selection_action_bar.dart`
- `lib/features/canvas/presentation/widgets/group_selection_action_bar.dart`
