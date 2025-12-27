import 'package:flutter/material.dart';

class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EditorAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('2D Animation Editor'),
      actions: [
        IconButton(
          onPressed: () {
            debugPrint('Save tapped (placeholder)');
          },
          icon: const Icon(Icons.save),
          tooltip: 'Save',
        ),
      ],
    );
  }
}
