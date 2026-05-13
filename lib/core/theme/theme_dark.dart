import 'package:flutter/material.dart';

class DarkTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF90CAF9),
      onPrimary: const Color(0xFF1A237E),
      primaryContainer: const Color(0xFFBBDEFB),
      secondary: const Color(0xFFB0BEC5),
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFF5F5F5),
      error: const Color(0xFFB00020),
    ),
    fontFamily: 'Roboto',
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF90CAF9),
      onPrimary: const Color(0xFF0D1B2A),
      primaryContainer: const Color(0xFF1B2838),
      secondary: const Color(0xFF607D8B),
      surface: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF0D0D0D),
      error: const Color(0xFFCF6679),
    ),
    fontFamily: 'Roboto',
  );
}
