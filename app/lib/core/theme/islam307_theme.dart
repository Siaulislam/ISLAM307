import 'package:flutter/material.dart';

/// ISLAM 307 design tokens — white, emerald, gold (original premium UI).
class Islam307Theme {
  static const white = Color(0xFFFFFFFF);
  static const emerald = Color(0xFF0D9488);
  static const emeraldDeep = Color(0xFF065F46);
  static const emeraldSoft = Color(0xFFECFDF5);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFF5E6B8);
  static const textPrimary = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const cardBorder = Color(0xFFE2E8F0);
  static const fieldFill = Color(0xFFF6F8FC);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          primary: emerald,
          secondary: gold,
          surface: white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: white,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: cardBorder),
          ),
          shadowColor: Colors.black26,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: emerald,
            foregroundColor: white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );

  static ThemeData get dark => light.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          brightness: Brightness.dark,
        ),
      );
}
