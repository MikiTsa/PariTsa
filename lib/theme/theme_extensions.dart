import 'package:flutter/material.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

/// BuildContext extension that returns the correct color for the current theme
/// (light or dark). Use `context.cPrimaryText` instead of
/// `AppColors.primaryText` in any widget that needs to adapt to dark mode.
extension AppThemeX on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cBackground    => _isDark ? const Color(0xFF0D1B24) : AppColors.background;
  Color get cCard          => _isDark ? const Color(0xFF152333) : AppColors.cardBackground;
  Color get cPrimaryText   => _isDark ? const Color(0xFFE0EEF2) : AppColors.primaryText;
  Color get cSecondaryText => _isDark ? const Color(0xFF5BB5C5) : AppColors.secondaryText;
  Color get cMutedText     => _isDark ? const Color(0xFF7AADA3) : AppColors.mutedText;
  Color get cDivider       => _isDark ? const Color(0xFF2A4A5A) : AppColors.divider;
  Color get cInputFill     => _isDark ? const Color(0xFF1A3040) : AppColors.inputFill;
  Color get cAppBar        => _isDark ? const Color(0xFF0D1B24) : AppColors.appBar;
}
