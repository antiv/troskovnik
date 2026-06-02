import 'package:flutter/material.dart';

/// Centralized Material 3 theme for the app.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF1B5E20); // dinar green

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
