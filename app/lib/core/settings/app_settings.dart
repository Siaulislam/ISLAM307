import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum QuranDisplayLanguage { urdu, english, arabicOnly }

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.quranLanguage = QuranDisplayLanguage.urdu,
    this.preferredTafsirSlug = 'ibn-kathir',
    this.fontScale = 1.0,
  });

  final ThemeMode themeMode;
  final QuranDisplayLanguage quranLanguage;
  final String preferredTafsirSlug;
  final double fontScale;

  AppSettings copyWith({
    ThemeMode? themeMode,
    QuranDisplayLanguage? quranLanguage,
    String? preferredTafsirSlug,
    double? fontScale,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      quranLanguage: quranLanguage ?? this.quranLanguage,
      preferredTafsirSlug: preferredTafsirSlug ?? this.preferredTafsirSlug,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _themeKey = 'theme_mode';
  static const _langKey = 'quran_lang';
  static const _tafsirKey = 'preferred_tafsir';
  static const _fontKey = 'font_scale';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final theme = ThemeMode.values[p.getInt(_themeKey) ?? ThemeMode.system.index];
    final lang = QuranDisplayLanguage.values[p.getInt(_langKey) ?? QuranDisplayLanguage.urdu.index];
    state = AppSettings(
      themeMode: theme,
      quranLanguage: lang,
      preferredTafsirSlug: p.getString(_tafsirKey) ?? 'ibn-kathir',
      fontScale: p.getDouble(_fontKey) ?? 1.0,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_themeKey, mode.index);
  }

  Future<void> setQuranLanguage(QuranDisplayLanguage lang) async {
    state = state.copyWith(quranLanguage: lang);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_langKey, lang.index);
  }

  Future<void> setPreferredTafsir(String slug) async {
    state = state.copyWith(preferredTafsirSlug: slug);
    final p = await SharedPreferences.getInstance();
    await p.setString(_tafsirKey, slug);
  }

  Future<void> setFontScale(double scale) async {
    state = state.copyWith(fontScale: scale.clamp(0.85, 1.6));
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_fontKey, state.fontScale);
  }

  Future<void> toggleTheme() async {
    final next = state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);
