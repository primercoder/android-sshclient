import 'package:flutter/material.dart';

class PinkTheme {
  static const _primary = Color(0xFFE91E63);
  static const _background = Color(0xFFFCE4EC);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFF8BBD0),
      secondary: const Color(0xFFF06292),
      surface: Colors.white,
      surfaceContainerHighest: _background,
      error: const Color(0xFFB00020),
    ),
    fontFamily: 'Roboto',
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFF48FB1),
      onPrimary: const Color(0xFF3E0020),
      primaryContainer: const Color(0xFF880E4F),
      secondary: const Color(0xFFF06292),
      surface: const Color(0xFF241B1F),
      surfaceContainerHighest: const Color(0xFF121212),
      error: const Color(0xFFCF6679),
    ),
    fontFamily: 'Roboto',
  );
}
