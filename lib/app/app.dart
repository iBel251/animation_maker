import 'package:flutter/material.dart';
import 'package:animation_maker/core/theme/app_theme.dart';
import 'package:animation_maker/features/canvas/presentation/screens/canvas_screen.dart';

export 'package:animation_maker/features/canvas/presentation/screens/canvas_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animation Maker',
      theme: AppTheme.light,
      home: const CanvasScreen(),
    );
  }
}


