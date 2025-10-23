import 'package:flutter/material.dart';

class AppTheme {
  // Light theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A5BA1),
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A5BA1),
        brightness: Brightness.light,
      ).surface,
    ),
  );

  // Dark theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A5BA1),
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A5BA1),
        brightness: Brightness.dark,
      ).surface,
    ),
  );
}
