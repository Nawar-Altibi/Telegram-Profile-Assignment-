import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 dark theme recoloured with the [AppColors] palette. Widgets
/// read most colours from [AppColors] directly; this only sets the defaults
/// (scaffold, accent, text) that stock Material widgets fall back to.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.scaffold,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.surface,
        primary: AppColors.accent,
      ),
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.primaryText,
        displayColor: AppColors.primaryText,
      ),
    );
  }
}
