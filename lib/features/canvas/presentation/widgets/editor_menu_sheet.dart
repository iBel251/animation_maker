import 'package:animation_maker/features/canvas/presentation/providers/canvas_notifier.dart';
import 'package:animation_maker/features/canvas/presentation/providers/image_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showEditorMenu({required BuildContext context}) {
  final isCompact = MediaQuery.of(context).size.width < 600;
  if (isCompact) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 16,
          bottom: MediaQuery.of(ctx).viewPadding.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(title: 'Menu', onClose: () => Navigator.of(ctx).pop()),
            const SizedBox(height: 8),
            const _EditorMenuContent(),
          ],
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Menu'),
        content: const SingleChildScrollView(child: _EditorMenuContent()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }
}

class _EditorMenuContent extends ConsumerStatefulWidget {
  const _EditorMenuContent();

  @override
  ConsumerState<_EditorMenuContent> createState() => _EditorMenuContentState();
}

class _EditorMenuContentState extends ConsumerState<_EditorMenuContent> {
  bool _gridEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Project settings'),
          onTap: () => Navigator.of(context).pop(),
        ),
        SwitchListTile(
          value: _gridEnabled,
          onChanged: (value) => setState(() => _gridEnabled = value),
          title: const Text('Grid'),
          secondary: const Icon(Icons.grid_on),
        ),
        SwitchListTile(
          value: ref.watch(
            editorViewModelProvider.select(
              (state) => state.joystickControllerEnabled,
            ),
          ),
          onChanged: (value) {
            final vm = ref.read(editorViewModelProvider.notifier);
            final enabled = ref.read(
              editorViewModelProvider.select(
                (state) => state.joystickControllerEnabled,
              ),
            );
            if (enabled != value) {
              vm.toggleJoystickController();
            }
          },
          title: const Text('Joystick controller'),
          secondary: const Icon(Icons.gamepad),
        ),
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text('Add image'),
          onTap: () async {
            final imageService = ref.read(imageServiceProvider);
            final editorVm = ref.read(editorViewModelProvider.notifier);
            Navigator.of(context).pop();
            final result = await imageService.pickAndPersistImage();
            if (result != null) {
              editorVm.addImageShape(result);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.movie),
          title: const Text('Add video'),
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
