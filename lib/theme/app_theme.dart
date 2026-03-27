import 'package:flutter/material.dart';
import 'package:expenses_tracker/theme/app_colors.dart';

abstract final class AppTheme {
  // ── Light ──────────────────────────────────────────────────────────────────

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        cardColor: AppColors.cardBackground,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.darkCyan,
          onSecondary: Colors.white,
          error: AppColors.oxidizedIron,
          onError: Colors.white,
          surface: AppColors.background,
          onSurface: AppColors.primaryText,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.appBarText,
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.background,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.cardBackground,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBackground,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.pearlAqua),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.pearlAqua),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.inputBorder, width: 2),
          ),
        ),
        dividerColor: AppColors.divider,
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
        ),
      );

  // ── Dark ───────────────────────────────────────────────────────────────────

  static const Color _darkBg     = Color(0xFF0D1B24);
  static const Color _darkCard   = Color(0xFF152333);
  static const Color _darkText   = Color(0xFFE0EEF2);
  static const Color _darkInput  = Color(0xFF1A3040);
  static const Color _darkDivider = Color(0xFF2A4A5A);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _darkBg,
        cardColor: _darkCard,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.balticBlue,
          onPrimary: Colors.white,
          secondary: AppColors.pacificCyan,
          onSecondary: Colors.white,
          error: AppColors.burntTangerine,
          onError: Colors.white,
          surface: _darkBg,
          onSurface: _darkText,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _darkBg,
          foregroundColor: _darkText,
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: _darkBg,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: _darkCard,
        ),
        cardTheme: CardThemeData(
          color: _darkCard,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.balticBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkInput,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.pacificCyan),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.pacificCyan),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.pacificCyan, width: 2),
          ),
        ),
        dividerColor: _darkDivider,
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.balticBlue,
        ),
      );
}
