import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Base palette ─────────────────────────────────────────────────────────
  static const Color balticBlue     = Color(0xFF127CA5);
  static const Color pacificCyan    = Color(0xFF358292);
  static const Color mutedTeal      = Color(0xFF88ACA2);
  static const Color wheat          = Color(0xFFECD9AF);
  static const Color lightBronze    = Color(0xFFE5A065);
  static const Color burntPeach     = Color(0xFFE4723E);
  static const Color burntTangerine = Color(0xFFDC4029);
  static const Color vividTangerine = Color(0xFFF08537);
  static const Color amberGlow      = Color(0xFFF8A036);

  // ── Semantic roles ────────────────────────────────────────────────────────
  static const Color background     = Colors.white;
  static const Color appBar         = Colors.white;
  static const Color appBarText     = primaryText;
  static const Color primary        = balticBlue;
  static const Color primaryText    = Color(0xFF1A2E38); // dark navy, tonal with palette
  static const Color secondaryText  = pacificCyan;
  static const Color mutedText      = mutedTeal;
  static const Color divider        = mutedTeal;
  static const Color inputFill      = Color(0xFFF0F6F5); // barely-visible teal tint
  static const Color inputBorder    = pacificCyan;
  static const Color cardBackground = Colors.white;
  static const Color deleteAction   = burntTangerine;

  // ── Transaction type colors ───────────────────────────────────────────────
  static const Color expense = burntTangerine; // warm red-orange
  static const Color income  = pacificCyan;    // teal
  static const Color saving  = amberGlow;      // soft amber

  // ── Balance box base colors (opacity applied in the widget) ───────────────
  static const Color balanceExpense = burntTangerine;
  static const Color balanceIncome  = balticBlue;
  static const Color balanceSaving  = lightBronze;

  // ── Aliases (old names used across other files) ───────────────────────────
  static const Color darkCyan     = pacificCyan;
  static const Color pearlAqua    = mutedTeal;
  static const Color oxidizedIron = burntTangerine;
  static const Color inkBlack     = Color(0xFF1A2E38);
}
