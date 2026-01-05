import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.seed);
    return ThemeData(
      colorScheme: colorScheme.copyWith(surface: AppColors.surface),
      useMaterial3: true,
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primary.withOpacity(0.2),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected)
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.6),
        ),
        trackColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.selected)
              ? colorScheme.primary.withOpacity(0.4)
              : colorScheme.onSurface.withOpacity(0.2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      scaffoldBackgroundColor: AppColors.surface,
      cardColor: AppColors.surface,
      dividerColor: AppColors.surfaceBorder,
      shadowColor: AppColors.shadow,
    );
  }
}


