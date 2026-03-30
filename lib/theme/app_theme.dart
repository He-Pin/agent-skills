// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// Accent color presets matching the original React app's OKLch color scheme.
/// Each preset provides light and dark variant colors.
class AccentPreset {
  final String key;
  final String label;
  final Color lightPrimary;
  final Color darkPrimary;
  final Color lightPrimaryForeground;
  final Color darkPrimaryForeground;

  const AccentPreset({
    required this.key,
    required this.label,
    required this.lightPrimary,
    required this.darkPrimary,
    required this.lightPrimaryForeground,
    required this.darkPrimaryForeground,
  });
}

/// All 6 accent color presets from the original app.
const List<AccentPreset> accentPresets = [
  AccentPreset(
    key: 'indigo',
    label: 'Indigo',
    lightPrimary: Color(0xFF4338CA), // oklch(0.55 0.24 270)
    darkPrimary: Color(0xFF818CF8), // oklch(0.72 0.18 270)
    lightPrimaryForeground: Colors.white,
    darkPrimaryForeground: Color(0xFF1E1B4B),
  ),
  AccentPreset(
    key: 'coral',
    label: 'Coral',
    lightPrimary: Color(0xFFDC4A3A), // oklch(0.58 0.2 25)
    darkPrimary: Color(0xFFF87171), // oklch(0.72 0.16 25)
    lightPrimaryForeground: Colors.white,
    darkPrimaryForeground: Color(0xFF450A0A),
  ),
  AccentPreset(
    key: 'teal',
    label: 'Teal',
    lightPrimary: Color(0xFF0D9488), // oklch(0.58 0.14 175)
    darkPrimary: Color(0xFF2DD4BF), // oklch(0.75 0.14 175)
    lightPrimaryForeground: Colors.white,
    darkPrimaryForeground: Color(0xFF042F2E),
  ),
  AccentPreset(
    key: 'amber',
    label: 'Amber',
    lightPrimary: Color(0xFFD97706), // oklch(0.6 0.18 80)
    darkPrimary: Color(0xFFFBBF24), // oklch(0.78 0.14 80)
    lightPrimaryForeground: Colors.white,
    darkPrimaryForeground: Color(0xFF451A03),
  ),
  AccentPreset(
    key: 'rose',
    label: 'Rose',
    lightPrimary: Color(0xFFE11D48), // oklch(0.55 0.22 350)
    darkPrimary: Color(0xFFFB7185), // oklch(0.72 0.17 350)
    lightPrimaryForeground: Colors.white,
    darkPrimaryForeground: Color(0xFF4C0519),
  ),
  AccentPreset(
    key: 'mono',
    label: 'Mono',
    lightPrimary: Color(0xFF374151), // oklch(0.45 0.01 260)
    darkPrimary: Color(0xFFD1D5DB), // oklch(0.8 0.01 260)
    lightPrimaryForeground: Colors.white,
    darkPrimaryForeground: Color(0xFF111827),
  ),
];

/// Build the light theme for the app.
ThemeData buildLightTheme(AccentPreset accent) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Geist',
    colorScheme: ColorScheme.light(
      primary: accent.lightPrimary,
      onPrimary: accent.lightPrimaryForeground,
      surface: const Color(0xFFF8FAFC),
      onSurface: const Color(0xFF0F172A),
      surfaceContainerHighest: const Color(0xFFE2E8F0),
      outline: const Color(0xFFCBD5E1),
    ),
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: Color(0xFFFFFFFE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent.lightPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent.lightPrimary,
        foregroundColor: accent.lightPrimaryForeground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent.lightPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: accent.lightPrimary.withValues(alpha: 0.3)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent.lightPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

/// Build the dark theme for the app.
ThemeData buildDarkTheme(AccentPreset accent) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Geist',
    colorScheme: ColorScheme.dark(
      primary: accent.darkPrimary,
      onPrimary: accent.darkPrimaryForeground,
      surface: const Color(0xFF0F172A),
      onSurface: const Color(0xFFF1F5F9),
      surfaceContainerHighest: const Color(0xFF1E293B),
      outline: const Color(0xFF334155),
    ),
    scaffoldBackgroundColor: const Color(0xFF020617),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1E293B),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent.darkPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent.darkPrimary,
        foregroundColor: accent.darkPrimaryForeground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent.darkPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: accent.darkPrimary.withValues(alpha: 0.3)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent.darkPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
