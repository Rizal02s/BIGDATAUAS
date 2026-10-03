import 'package:flutter/material.dart';

abstract final class PeronaColors {
  static const ink = Color(0xff2e381e);
  static const muted = Color(0xff77765f);
  static const forest = Color(0xff58730b);
  static const brandGreen = Color(0xff8cb719);
  static const lime = Color(0xffe6efbd);
  static const background = Color(0xfffaf5e7);
  static const surface = Color(0xfffffcf4);
  static const border = Color(0xffe5dec9);
}

ThemeData peronaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PeronaColors.forest,
    primary: PeronaColors.brandGreen,
    onPrimary: PeronaColors.ink,
    secondary: PeronaColors.lime,
    surface: PeronaColors.surface,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  return base.copyWith(
    scaffoldBackgroundColor: PeronaColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: PeronaColors.ink,
      displayColor: PeronaColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PeronaColors.background,
      foregroundColor: PeronaColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: PeronaColors.surface,
      margin: EdgeInsets.zero,
      shape: rounded.copyWith(
        side: const BorderSide(color: PeronaColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PeronaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PeronaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PeronaColors.forest, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: PeronaColors.ink,
        backgroundColor: PeronaColors.brandGreen,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: PeronaColors.forest),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PeronaColors.forest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: PeronaColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PeronaColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: PeronaColors.lime,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
          color: PeronaColors.ink,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PeronaColors.lime,
      foregroundColor: PeronaColors.ink,
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(color: PeronaColors.border, space: 24),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
