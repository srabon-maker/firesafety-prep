import 'package:flutter/material.dart';

class AppColors {
  static const Color maroon = Color(0xFF650D18);
  static const Color deepMaroon = Color(0xFF36060D);
  static const Color red = Color(0xFFE32636);
  static const Color cream = Color(0xFFFFF8F4);
  static const Color ink = Color(0xFF27191B);
}

class AppTheme {
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
