import 'package:flutter/material.dart';

class AppColors {
  static const Color maroon = Color(0xFF650D18);
  static const Color deepMaroon = Color(0xFF36060D);
  static const Color red = Color(0xFFE32636);
  static const Color cream = Color(0xFFF8F9FC);
  static const Color ink = Color(0xFF27191B);
}

class AppTheme {
  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.maroon,
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFFFFB3BC) : AppColors.maroon,
      onPrimary: dark ? const Color(0xFF400811) : Colors.white,
      surface: dark ? const Color(0xFF211D21) : Colors.white,
      onSurface: dark ? const Color(0xFFF8F0F2) : AppColors.ink,
      onSurfaceVariant: dark ? const Color(0xFFD3C3C8) : const Color(0xFF655B60),
      outlineVariant: dark ? const Color(0xFF55474D) : const Color(0xFFE3DDE0),
    );
    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
    // Use platform fallback for Bengali; no network font downloads at runtime.
    final typography = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamilyFallback: const ['Noto Sans Bengali', 'sans-serif'],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color),
    );
    return base.copyWith(
      scaffoldBackgroundColor: dark ? const Color(0xFF151417) : AppColors.cream,
      textTheme: typography.copyWith(
        titleLarge: typography.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
        titleMedium: typography.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: typography.bodyMedium?.copyWith(height: 1.45),
      ),
      cardColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF27171B) : AppColors.maroon,
        foregroundColor: Colors.white, centerTitle: false, elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface, elevation: 0, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface, indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: dark ? const Color(0xFF342C32) : const Color(0xFFF3F0F2),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant, suffixIconColor: scheme.onSurfaceVariant,
        border: inputBorder(scheme.outlineVariant),
        enabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(scheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48), shape: shape,
      )),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48), shape: shape,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48), shape: shape,
      )),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary, linearTrackColor: scheme.primaryContainer,
        linearMinHeight: 6,
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: shape),
    );
  }
}
