import 'package:flutter/material.dart';

class OrangeTheme {
  static const _primary = Color(0xFFFF9800);
  static const _background = Color(0xFFFFF3E0);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE0B2),
      secondary: const Color(0xFFFF7043),
      surface: Colors.white,
      surfaceContainerHighest: _background,
      error: const Color(0xFFB00020),
    ),
    fontFamily: 'Roboto',
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFFFB74D),
      onPrimary: const Color(0xFF3E1A00),
      primaryContainer: const Color(0xFFE65100),
      secondary: const Color(0xFFFF8A65),
      surface: const Color(0xFF241E1B),
      surfaceContainerHighest: const Color(0xFF121212),
      error: const Color(0xFFCF6679),
    ),
    fontFamily: 'Roboto',
  );
}
