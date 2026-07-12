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
  static const darkBg = Color(0xFF0B1220);
  static const darkCard = Color(0xFF121A2A);
  static const darkBorder = Color(0xFF243044);

  static const arabicFont = 'NotoNaskhArabic';
  static const urduFont = 'NotoNastaliqUrdu';

  static TextStyle arabic({double size = 24, FontWeight weight = FontWeight.w400, Color? color, double height = 2.0}) {
    return TextStyle(
      fontFamily: arabicFont,
      fontSize: size,
      fontWeight: weight,
      color: color ?? textPrimary,
      height: height,
    );
  }

  static TextStyle urdu({double size = 18, Color? color, double height = 1.9}) {
    return TextStyle(
      fontFamily: urduFont,
      fontSize: size,
      color: color ?? textMuted,
      height: height,
    );
  }

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
        fontFamily: 'Roboto',
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
        ),
        chipTheme: ChipThemeData(
          backgroundColor: emeraldSoft,
          selectedColor: emerald,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          secondaryLabelStyle: const TextStyle(color: white, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: fieldFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          brightness: Brightness.dark,
          primary: emerald,
          secondary: gold,
          surface: darkCard,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg,
          foregroundColor: white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: darkBorder),
          ),
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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      );
}
