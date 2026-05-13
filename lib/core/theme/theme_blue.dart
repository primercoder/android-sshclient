import 'package:flutter/material.dart';

class BlueTheme {
  static const _primary = Color(0xFF1976D2);
  static const _background = Color(0xFFE3F2FD);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFBBDEFB),
      secondary: const Color(0xFF03A9F4),
      surface: Colors.white,
      surfaceContainerHighest: _background,
      error: const Color(0xFFB00020),
    ),
    fontFamily: 'Roboto',
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF64B5F6),
      onPrimary: const Color(0xFF00264B),
      primaryContainer: const Color(0xFF0D47A1),
      secondary: const Color(0xFF4FC3F7),
      surface: const Color(0xFF1B1F24),
      surfaceContainerHighest: const Color(0xFF121212),
      error: const Color(0xFFCF6679),
    ),
    fontFamily: 'Roboto',
  );
}
