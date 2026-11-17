import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only presentation preferences; never stores authentication data.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();
  static const _localeKey = 'app_locale';
  static const _themeKey = 'app_theme_mode';

  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('bn'));
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    locale.value = Locale(preferences.getString(_localeKey) == 'en' ? 'en' : 'bn');
    switch (preferences.getString(_themeKey)) {
      case 'light':
        themeMode.value = ThemeMode.light;
        break;
      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;
      default:
        themeMode.value = ThemeMode.system;
    }
  }

  Future<void> setLanguage(String language) async {
    final value = language == 'en' ? 'en' : 'bn';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localeKey, value);
    locale.value = Locale(value);
  }

  Future<void> setTheme(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, mode.name);
    themeMode.value = mode;
  }
}

class AppText {
  static String of(BuildContext context, String bn, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : bn;
}
