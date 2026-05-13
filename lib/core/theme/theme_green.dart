import 'package:flutter/material.dart';

class GreenTheme {
  static const _primary = Color(0xFF4CAF50);
  static const _onPrimary = Color(0xFFFFFFFF);
  static const _primaryContainer = Color(0xFFC8E6C9);
  static const _background = Color(0xFFF1F8E9);
  static const _surface = Color(0xFFFFFFFF);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: _primary,
      onPrimary: _onPrimary,
      primaryContainer: _primaryContainer,
      secondary: const Color(0xFF8BC34A),
      surface: _surface,
      surfaceContainerHighest: _background,
      error: const Color(0xFFB00020),
    ),
    fontFamily: 'Roboto',
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF81C784),
      onPrimary: const Color(0xFF003300),
      primaryContainer: const Color(0xFF1B5E20),
      secondary: const Color(0xFFAED581),
      surface: const Color(0xFF1B1F1B),
      surfaceContainerHighest: const Color(0xFF121212),
      error: const Color(0xFFCF6679),
    ),
    fontFamily: 'Roboto',
  );
}
