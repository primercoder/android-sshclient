import 'package:flutter/material.dart';
import 'theme_green.dart';
import 'theme_blue.dart';
import 'theme_pink.dart';
import 'theme_dark.dart';
import 'theme_orange.dart';

enum AppThemeType {
  green,
  blue,
  pink,
  dark,
  orange,
}

extension AppThemeTypeExtension on AppThemeType {
  String get label {
    switch (this) {
      case AppThemeType.green: return '清新绿';
      case AppThemeType.blue: return '海洋蓝';
      case AppThemeType.pink: return '樱花粉';
      case AppThemeType.dark: return '暗夜黑';
      case AppThemeType.orange: return '暖阳橙';
    }
  }

  String get icon {
    switch (this) {
      case AppThemeType.green: return '🌿';
      case AppThemeType.blue: return '🌊';
      case AppThemeType.pink: return '🌸';
      case AppThemeType.dark: return '🌙';
      case AppThemeType.orange: return '☀️';
    }
  }

  ThemeData get lightTheme {
    switch (this) {
      case AppThemeType.green: return GreenTheme.light;
      case AppThemeType.blue: return BlueTheme.light;
      case AppThemeType.pink: return PinkTheme.light;
      case AppThemeType.dark: return DarkTheme.light;
      case AppThemeType.orange: return OrangeTheme.light;
    }
  }

  ThemeData get darkTheme {
    switch (this) {
      case AppThemeType.green: return GreenTheme.dark;
      case AppThemeType.blue: return BlueTheme.dark;
      case AppThemeType.pink: return PinkTheme.dark;
      case AppThemeType.dark: return DarkTheme.dark;
      case AppThemeType.orange: return OrangeTheme.dark;
    }
  }
}
