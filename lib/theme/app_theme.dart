import 'package:flutter/material.dart';

class AppColors {
  static const Color maroon = Color(0xFF650D18);
  static const Color deepMaroon = Color(0xFF36060D);
  static const Color red = Color(0xFFE32636);
  static const Color cream = Color(0xFFFFF8F4);
  static const Color ink = Color(0xFF27191B);
}

class AppTheme {
  static ThemeData get darkTheme {
    const surface = Color(0xFF211D21);
    const background = Color(0xFF151417);
    const foreground = Color(0xFFF8F0F2);
    const muted = Color(0xFFD3C3C8);
    const accent = Color(0xFFFFB3BC);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.maroon,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      onPrimary: const Color(0xFF400811),
      surface: surface,
      onSurface: foreground,
      onSurfaceVariant: muted,
      outlineVariant: const Color(0xFF55474D),
      surfaceContainerHighest: const Color(0xFF383037),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      cardColor: surface,
      dividerColor: scheme.outlineVariant,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF27171B),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF342C32),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.maroon,
        primary: AppColors.maroon,
      ),
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6ECE8),
        hintStyle: const TextStyle(
          color: Color(0xFF8C7777),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
